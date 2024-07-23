locals {
  managed_zones        = coalesce(var.domain_config.managed_zones, {})
  auto_cloud_dns_setup = coalesce(var.domain_config.auto_cloud_dns_setup, false)

  # Lookup table which resolves a service to a { dns_name } or { zone_name }
  _managed_zones_lut = {
    for name, config in var.components : name => try(local.managed_zones[config.name], local.managed_zones["default"])
    if local.auto_cloud_dns_setup
  }

  # Create a temporary grouping of DNS names with components names (dns_names may be duplicated)
  _dns_names_with_services = flatten([
    for name, config in var.components : [
      {
        dns_name     = local._managed_zones_lut[name]["dns_name"]
        service_name = name
      }
    ] if try(local._managed_zones_lut[name]["dns_name"], null) != null
  ])

  # Create a mapping of DNS names to a singular name which combines the names of the components that use it
  # e.g. { default = { dns_name = "example.com." } } => { "example.com." = "dtsx-langflow-assistants-zone" }
  dns_name_to_combined_name = {
    for dns_name in toset(local._dns_names_with_services[*]["dns_name"]) : dns_name =>
    join("-", [for pair in local._dns_names_with_services : pair["service_name"] if pair["dns_name"] == dns_name])
    if local.auto_cloud_dns_setup
  }

  # Find the zone name given a service name (e.g. "langflow" => "dtsx-langflow-assistants-zone")
  # Passes through a google_dns_managed_zone data source for validation purposes (instead of blindly using the value)
  managed_zones_lut = {
    for name, config in var.components : name =>
    (local._managed_zones_lut[config.name]["dns_name"] != null
      ? google_dns_managed_zone.zones[
        [for pair in local._dns_names_with_services : pair["dns_name"] if pair["service_name"] == name][0]
      ].name
    : local._managed_zones_lut[config.name]["zone_name"])
    if local.auto_cloud_dns_setup
  }
}

resource "google_dns_managed_zone" "zones" {
  for_each = local.dns_name_to_combined_name
  name     = "dtsx-${each.value}-zone"
  dns_name = each.key
  project  = local.project_id
}

resource "google_dns_record_set" "a_records" {
  for_each = {
    for name, config in var.components : name => config
    if local.auto_cloud_dns_setup && config.domain != null
  }

  name         = "${each.value.domain}."
  managed_zone = local.managed_zones_lut[each.key]
  type         = "A"
  ttl          = 300
  rrdatas      = [module.lb-http[0].external_ip]
  project      = local.project_id
}
