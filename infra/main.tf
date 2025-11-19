# APIs
locals { apis = [
  "run.googleapis.com","artifactregistry.googleapis.com",
  "cloudbuild.googleapis.com","iam.googleapis.com","bigquery.googleapis.com"
]}

resource "google_project_service" "apis" {
  for_each = toset(local.apis)
  project  = var.project_id
  service  = each.value
  disable_on_destroy = false
}

# Artifact Registry
resource "google_artifact_registry_repository" "repo" {
  project = var.project_id
  location = var.region
  repository_id = var.ar_repo
  format = "DOCKER"
  description = "Containers for Cloud Run"
  depends_on = [google_project_service.apis]
}

# Runtime SA
resource "google_service_account" "runtime" {
  account_id   = var.runtime_sa_name
  display_name = "FinOps runtime SA"
}

# BigQuery
resource "google_bigquery_dataset" "ds" {
  dataset_id = var.bq_dataset
  location   = "US"
  description = "FinOps curated dataset"
  depends_on = [google_project_service.apis]
}

resource "google_bigquery_table" "alerts" {
  dataset_id = google_bigquery_dataset.ds.dataset_id
  table_id   = var.bq_table
  schema = jsonencode([
    { name = "id",         type = "STRING",    mode = "REQUIRED" },
    { name = "event_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "event_type", type = "STRING",    mode = "NULLABLE" },
    { name = "payload",    type = "STRING",    mode = "NULLABLE", description = "raw JSON" }
  ])
}

# Runtime SA permissions (BQ read/write; Run reads secrets/metadata handled by env)
resource "google_project_iam_member" "runtime_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_project_iam_member" "runtime_bq_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Cloud Build SA
locals { cloud_build_sa = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com" }

resource "google_project_iam_member" "cb_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.cloud_build_sa}"
}

resource "google_project_iam_member" "cb_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.cloud_build_sa}"
}

resource "google_service_account_iam_member" "cb_impersonate_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloud_build_sa}"
}

# Cloud Build trigger (GitHub App connection assumed)
resource "google_cloudbuild_trigger" "app" {
  name        = "finops-app-deploy"
  description = "Build from app/ and deploy to Cloud Run"
  filename    = "cloudbuild.yaml"
  project     = var.project_id

  github {
    owner = var.repo_owner
    name  = var.repo_name
    push  { branch = "^main$" }
  }

  substitutions = {
    _SERVICE_NAME     = var.service_name
    _REGION           = var.region
    _AR_REPO          = var.ar_repo
    _RUNTIME_SA_EMAIL = google_service_account.runtime.email
    _BQ_DATASET       = var.bq_dataset
    _BQ_ALERTS_TABLE  = var.bq_table
  }

  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.repo,
    google_service_account.runtime,
    google_project_iam_member.cb_ar_writer,
    google_project_iam_member.cb_run_admin,
    google_service_account_iam_member.cb_impersonate_runtime
  ]
}

