output "runtime_service_account" { value = google_service_account.runtime.email }

output "artifact_registry_repo"  { value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.ar_repo}" }

output "cloud_build_sa"          { value = "${data.google_project.this.number}@cloudbuild.gserviceaccount.com" }

