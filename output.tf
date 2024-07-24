output "load_balancer_ip" {
  description = "The IP address of the created ELB through which to access the Cloud Run services w/ a custom domain"
  value = try(module.gcp_infra[0].load_balancer_ip, null)
}

output "project_id" {
  description = "The ID of the created project (or regurgitated if an existing one was used)"
  value = try(module.gcp_infra[0].project_id, null)
}

output "name_servers" {
  description = "The nameservers that need to be set for any created managed zones, if necessary"
  value = try(module.gcp_infra[0].name_servers, null)
}

output "service_uris" {
  description = "The map of the services to the URLs you would use to access them"
  value = {
    for key, uri in {
      langflow   = try(var.langflow.domain, null) != null ? ["https://${var.langflow.domain}"] : module.langflow[*].service_uri
      assistants = try(var.assistants.domain, null) != null ? ["https://${var.assistants.domain}"] : module.assistants[*].service_uri
    } : key => uri[0] if length(uri) > 0
  }
}

output "astra_vector_dbs" {
  description = "A map of DB IDs => DB info for all of the dbs created (from the `assistants` module and the `vector_dbs` module)"
  value = zipmap(concat(module.assistants[*].db_id, values(module.vector_dbs)[*].db_id), concat(module.assistants[*].db_info, values(module.vector_dbs)[*].db_info))
}
