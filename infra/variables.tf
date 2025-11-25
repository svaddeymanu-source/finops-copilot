variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "us-central1"
}

variable "repo_owner" { type = string } # GitHub org/user

variable "repo_name" { type = string } # GitHub repo

variable "service_name" {
  type    = string
  default = "finops-controller"
}

variable "ar_repo" {
  type    = string
  default = "finops-app"
}

variable "runtime_sa_name" {
  type    = string
  default = "finops-runtime"
}

variable "bq_dataset" {
  type    = string
  default = "finops_curated"
}

variable "bq_table" {
  type    = string
  default = "cur_alerts"
}
# Image built by Cloud Build and passed in at apply time
variable "controller_image" {
  type        = string
  description = "Fully-qualified image with digest for Cloud Run (e.g. us-central1-docker.pkg.dev/PROJECT/finops-app/finops-controller@sha256:...)"
  nullable = false
  default  = null
  # validation {
  #   condition     = length(var.controller_image) > 0 && can(regex("@sha256:", var.controller_image))
  #   error_message = "controller_image must be a non-empty image URI with a digest (…@sha256:<digest>)."
  # }
}
# Secrets you want to mount into Cloud Run (example: Slack webhook)
variable "slack_secret_name" { 
  type = string 
  default = "finops-slack-webhook" 
}

variable "controller_url" {
  type        = string
  default     = null
  description = ""
}