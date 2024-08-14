locals {
  name = "langflow"

  container_info = {
    image_name    = "langflowai/langflow"
    port          = 7860
    health_path   = "/health"
    csql_instance = try(google_sql_database_instance.this[0].connection_name, null)
  }

  using_managed_db = var.config.postgres_db != null

  postgres_url = (local.using_managed_db
    ? "postgres://psqladmin:${random_string.admin_password[0].result}@/${google_sql_database.this[0].name}?host=/cloudsql/${google_sql_database_instance.this[0].connection_name}"
    : null
  )

  env_override = {
    for k, v in {
      LANGFLOW_DATABASE_URL    = local.postgres_url
      LANGFLOW_LOAD_FLOWS_PATH = var.config.default_flows != null ? "/app/default-flows" : null
    } : k => v if v != null
  }

  merged_env        = merge(try(coalesce(var.config.containers.env), {}), local.env_override)
  merged_containers = merge(try(coalesce(var.config.containers), {}), { env = local.merged_env })
  merged_config     = merge(try(coalesce(var.config), {}), { containers = local.merged_containers })
}

module "cloud_run_deployment" {
  source = "../cloud_run_deployment"

  name             = local.name
  container_info   = local.container_info
  infrastructure   = var.infrastructure
  config           = local.merged_config
  using_managed_db = local.using_managed_db

  files_to_mount = {
    folder     = "/app/default-flows"
    key_prefix = "lflow-flows-"
    files      = coalesce(var.config.default_flows, [])
  }
}

resource "google_sql_database_instance" "this" {
  count = local.using_managed_db ? 1 : 0

  name             = "dtsx-langflow-postgres-main-instance"
  database_version = "POSTGRES_16"
  project          = var.infrastructure.project_id

  region              = var.config.postgres_db.region
  deletion_protection = var.config.postgres_db.deletion_protection

  settings {
    tier = var.config.postgres_db.tier

    ip_configuration {
      ssl_mode = "ENCRYPTED_ONLY"
    }

    disk_size             = try(coalesce(var.config.postgres_db.initial_storage), 10)
    disk_autoresize_limit = try(coalesce(var.config.postgres_db.max_storage), 10)
  }
}

resource "google_sql_database" "this" {
  count = local.using_managed_db ? 1 : 0

  name     = "dtsx-langflow-postgres-db"
  instance = google_sql_database_instance.this[0].name
  project  = var.infrastructure.project_id

  depends_on = [google_sql_user.admin]
}

resource "random_string" "admin_password" {
  count = local.using_managed_db ? 1 : 0

  length           = 16
  override_special = "%*()-_=+[]{}?"
}

resource "google_sql_user" "admin" {
  count = local.using_managed_db ? 1 : 0

  name     = "psqladmin"
  instance = google_sql_database_instance.this[0].name
  password = random_string.admin_password[0].result
  project  = var.infrastructure.project_id
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
