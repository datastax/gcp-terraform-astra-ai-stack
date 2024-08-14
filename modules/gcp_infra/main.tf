locals {
  project_id = coalesce(var.project_config.project_id, try(module.project-factory[0].project_id, null))
  location   = try(coalesce(var.deployment_defaults.location), data.google_cloud_run_locations.available.locations[0])
}

data "google_cloud_run_locations" "available" {
  project = local.project_id
}

resource "random_id" "proj_name" {
  byte_length = 4
}

module "project-factory" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  count = var.project_config.create_project != null ? 1 : 0

  name            = coalesce(var.project_config.create_project.name, "dtsx-${random_id.proj_name.hex}")
  org_id          = var.project_config.create_project.org_id
  billing_account = var.project_config.create_project.billing_account
  activate_apis = compact([
    "run.googleapis.com",
    local.auto_cloud_dns_setup ? "dns.googleapis.com" : null,
    var.using_cloud_sql ? "sqladmin.googleapis.com" : null,
    "secretmanager.googleapis.com",
  ])
}

resource "random_id" "url_map" {
  keepers = {
    instances = base64encode(jsonencode(values(var.components)[*].domain))
  }
  byte_length = 1
}

locals {
  using_custom_domains = length([for config in var.components : 1 if config.domain != null]) > 0
}

resource "google_compute_url_map" "url_map" {
  count = local.using_custom_domains ? 1 : 0

  name    = "dtsx-url-map-${random_id.url_map.hex}"
  project = local.project_id

  dynamic "host_rule" {
    for_each = {
      for name, config in var.components : name => config.domain
      if config.domain != null
    }

    content {
      hosts        = [host_rule.value]
      path_matcher = host_rule.key
    }
  }

  dynamic "path_matcher" {
    for_each = {
      for name, config in var.components : name => config
      if config.domain != null
    }

    content {
      name            = path_matcher.key
      default_service = module.lb-http[0].backend_services[path_matcher.key].id
    }
  }

  default_url_redirect {
    strip_query            = false
    redirect_response_code = "FOUND"
  }
}

module "lb-http" {
  count = local.using_custom_domains ? 1 : 0

  source  = "terraform-google-modules/lb-http/google//modules/serverless_negs"
  version = "~> 10.0"

  name    = "dtsx-lb-${random_id.url_map.hex}"
  project = local.project_id

  ssl                             = true
  managed_ssl_certificate_domains = compact(values(var.components)[*].domain)
  random_certificate_suffix       = true
  https_redirect                  = true
  url_map                         = try(google_compute_url_map.url_map[0].self_link, null)
  create_url_map                  = false

  backends = {
    for name, component in var.components : name => {
      description = null
      groups = [
        { group = google_compute_region_network_endpoint_group.serverless_neg[name].id }
      ]
      enable_cdn = false
      iap_config = {
        enable = false
      }
      log_config = {
        enable = false
      }
    }
  }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  for_each = var.components

  name                  = "dtsx-${each.key}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = local.location
  project               = local.project_id

  cloud_run {
    service = each.value.service_name
  }
}
