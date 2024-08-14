locals {
  csql_instances = var.using_managed_db ? [var.container_info.csql_instance] : []

  files_to_mount = {
    for file in try(coalesce(var.files_to_mount.files), []) : "${substr(sha256(file), 0, 12)}-${replace(basename(file), "[^a-zA-Z0-9_-.]", "")}" => file
  }

  mounting_files = length(local.files_to_mount) != 0

  service_name = "${var.name}-service"
}

resource "google_secret_manager_secret" "flow_secrets" {
  for_each  = local.files_to_mount
  project   = var.infrastructure.project_id
  secret_id = "${var.files_to_mount.key_prefix}${replace(each.key, ".", "_")}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "flow_secret_versions" {
  for_each    = local.files_to_mount
  secret      = google_secret_manager_secret.flow_secrets[each.key].name
  secret_data = file(each.value)
}

resource "google_cloud_run_v2_service" "this" {
  name     = local.service_name
  project  = var.infrastructure.project_id
  location = var.config.deployment.location

  template {
    service_account = google_service_account.cloud_run_sa.email

    containers {
      image   = "${var.container_info.image_name}:${try(coalesce(var.config.deployment.image_version), "latest")}"
      command = var.container_info.entrypoint

      liveness_probe {
        http_get {
          path = var.container_info.health_path
        }
        initial_delay_seconds = 120
      }

      resources {
        limits = {
          cpu    = try(coalesce(var.config.containers.cpu), "1")
          memory = try(coalesce(var.config.containers.memory), "2048Mi")
        }
      }

      ports {
        container_port = var.container_info.port
        name           = "http1"
      }

      dynamic "env" {
        for_each = try(coalesce(var.config.containers.env), {})

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "volume_mounts" {
        for_each = toset(local.csql_instances)

        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      dynamic "volume_mounts" {
        for_each = local.files_to_mount

        content {
          name       = google_secret_manager_secret.flow_secrets[volume_mounts.key].secret_id
          mount_path = var.files_to_mount.folder
        }
      }
    }

    scaling {
      min_instance_count = try(coalesce(var.config.deployment.min_instances), 0)
      max_instance_count = try(coalesce(var.config.deployment.max_instances), 20)
    }

    dynamic "volumes" {
      for_each = toset(local.csql_instances)

      content {
        name = "cloudsql"

        cloud_sql_instance {
          instances = [var.container_info.csql_instance]
        }
      }
    }

    dynamic "volumes" {
      for_each = local.files_to_mount

      content {
        name = google_secret_manager_secret.flow_secrets[volumes.key].secret_id

        secret {
          secret = google_secret_manager_secret.flow_secrets[volumes.key].secret_id

          items {
            path    = volumes.key
            version = "latest"
          }
        }
      }
    }
  }

  ingress = var.config.domain != null ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : "INGRESS_TRAFFIC_ALL"
}

output "service_uri" {
  value = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  value = local.service_name
}
