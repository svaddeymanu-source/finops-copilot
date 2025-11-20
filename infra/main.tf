terraform {
  backend "gcs" {
    bucket = "tfstate-optical-office-475814-t3-prod"
    prefix = "envs/prod" # folder-like path inside the bucket
  }
}

# APIs
locals { apis = [
  "run.googleapis.com", "artifactregistry.googleapis.com",
  "cloudbuild.googleapis.com", "iam.googleapis.com", "bigquery.googleapis.com"
] }

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Artifact Registry
resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.ar_repo
  format        = "DOCKER"
  description   = "Containers for Cloud Run"
  depends_on    = [google_project_service.apis]
}

# BigQuery
resource "google_bigquery_dataset" "ds" {
  dataset_id  = var.bq_dataset
  location    = "US"
  description = "FinOps curated dataset"
  depends_on  = [google_project_service.apis]
}

resource "google_bigquery_table" "alerts" {
  dataset_id = google_bigquery_dataset.ds.dataset_id
  table_id   = var.bq_table
  schema = jsonencode([
    { name = "id", type = "STRING", mode = "REQUIRED" },
    { name = "event_time", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "event_type", type = "STRING", mode = "NULLABLE" },
    { name = "payload", type = "STRING", mode = "NULLABLE", description = "raw JSON" }
  ])
}

# Runtime SA
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = var.runtime_sa_name
  display_name = "FinOps runtime SA"
}

# Runtime SA permissions (BQ read/write; Artifact Registry read)
locals {
  runtime_roles = [
    "roles/bigquery.dataEditor",
    "roles/bigquery.user",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "runtime_roles" {
  for_each = toset(local.runtime_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# Allow runtime SA to read the Slack secret
resource "google_secret_manager_secret_iam_member" "runtime_slack_access" {
  project   = var.project_id
  secret_id = var.slack_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}

# Cloud Build SA
locals {
  cloud_build_sa = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com"
  cb_roles = toset([
    "roles/serviceusage.serviceUsageAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/artifactregistry.admin",
    "roles/run.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/secretmanager.admin",
  ])
}

resource "google_project_iam_member" "cb_roles" {
  for_each = local.cb_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.cloud_build_sa}"
}

resource "google_service_account_iam_member" "cb_impersonate_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.cloud_build_sa}"
}

resource "google_cloud_run_service" "controller" {
  name     = var.service_name
  project  = var.project_id
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.runtime.email

      containers {
        image = var.image

        # Example: mount Slack webhook from Secret Manager into env var
        env {
          name = "SLACK_WEBHOOK_URL"
          value_from {
            secret_key_ref {
              key  = "latest"
              name = var.slack_secret_name
            }
          }
        }

        # If your app listens on 8080, Cloud Run detects it automatically.
        # Add ports { name = "http1" container_port = 8080 } only if needed.
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [
    google_project_iam_member.runtime_roles,
    google_secret_manager_secret_iam_member.runtime_slack_access
  ]
}
