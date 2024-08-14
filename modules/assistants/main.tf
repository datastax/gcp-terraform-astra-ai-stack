module "assistants_api_db" {
  source = "../astra_db"

  cloud_provider = var.infrastructure.cloud_provider

  config = {
    name                = "assistant_api_db"
    keyspaces           = ["assistant_api"]
    regions             = try(coalesce(var.config.astra_db.regions), null)
    deletion_protection = try(coalesce(var.config.astra_db.deletion_protection), null)
    cloud_provider      = try(coalesce(var.config.astra_db.cloud_provider), null)
  }
}

locals {
  name = "astra-assistants"

  container_info = {
    image_name   = "datastax/astra-assistants"
    port         = 8000
    entrypoint   = ["poetry", "run", "uvicorn", "impl.main:app", "--host", "0.0.0.0", "--port", "8000"]
    health_path  = "/v1/health"
  }
}

module "cloud_run_deployment" {
  source         = "../cloud_run_deployment"
  name           = local.name
  container_info = local.container_info
  config         = var.config
  infrastructure = var.infrastructure
}

output "name" {
  value = local.name
}

output "service_name" {
  value = module.cloud_run_deployment.service_name
}

output "service_uri" {
  value = module.cloud_run_deployment.service_uri
}

output "db_id" {
  value = module.assistants_api_db.db_id
}

output "db_info" {
  value = module.assistants_api_db.db_info
}
