variable "project_id" { type = string }

variable "region" {
  type    = string
  default = "us-central1"
}

variable "repo_owner" { type = string } # GitHub org/user

variable "repo_name"  { type = string } # GitHub repo

variable "service_name" {
  type    = string
  default = "finops-controller"
}

variable "ar_repo" {
  type    = string
  default = "containers"
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

