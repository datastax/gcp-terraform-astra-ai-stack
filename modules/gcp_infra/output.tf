output "project_id" {
  value = local.project_id
}

output "load_balancer_ip" {
  value = try(module.lb-http[0].external_ip, null)
}

output "location" {
  value = local.location
}

output "name_servers" {
  value = {
    for name, zone in google_dns_managed_zone.zones : name => zone.name_servers
  }
}
