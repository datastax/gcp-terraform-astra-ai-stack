resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.this.location
  service  = google_cloud_run_v2_service.this.name
  project  = var.infrastructure.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_service_account" "cloud_run_sa" {
  project    = var.infrastructure.project_id
  account_id = "cr-${var.name}-sa"
}

resource "google_secret_manager_secret_iam_member" "secret_accessor" {
  for_each  = local.files_to_mount
  project   = var.infrastructure.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
  secret_id = google_secret_manager_secret.flow_secrets[each.key].id
}

resource "google_project_iam_member" "cloud_sql_client" {
  count   = var.using_managed_db ? 1 : 0
  project = var.infrastructure.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
