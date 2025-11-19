# FinOps Cloud Run Mono-Repo

Complete infrastructure-as-code and application code for a GCP FinOps Cloud Run service with Terraform, Cloud Build, Artifact Registry, and BigQuery integration.

## Architecture

- **Infrastructure**: Terraform (Google provider) manages all GCP resources
- **CI/CD**: Cloud Build trigger automatically builds and deploys on push to `main`
- **Container Registry**: Artifact Registry (not GCR) in `us-central1` by default
- **Runtime**: Cloud Run service with dedicated Service Account for BigQuery access
- **Data**: BigQuery dataset and table for storing FinOps alerts/events

## Prerequisites

1. GCP project with billing enabled
2. Terraform >= 1.0 installed
3. `gcloud` CLI configured with appropriate permissions
4. GitHub repository with the "Google Cloud Build" GitHub App installed

## Setup

### 1. Initialize and Apply Terraform

```bash
cd infra
terraform init
terraform apply \
  -var="project_id=<YOUR_GCP_PROJECT_ID>" \
  -var="region=us-central1" \
  -var="repo_owner=<YOUR_GITHUB_ORG_OR_USERNAME>" \
  -var="repo_name=<YOUR_GITHUB_REPO_NAME>"
```

**Required Variables:**
- `project_id`: Your GCP project ID
- `repo_owner`: GitHub organization or username
- `repo_name`: GitHub repository name

**Optional Variables (with defaults):**
- `region`: GCP region (default: `us-central1`)
- `service_name`: Cloud Run service name (default: `finops-controller`)
- `ar_repo`: Artifact Registry repository name (default: `containers`)
- `runtime_sa_name`: Runtime service account name (default: `finops-runtime`)
- `bq_dataset`: BigQuery dataset ID (default: `finops_curated`)
- `bq_table`: BigQuery table ID (default: `cur_alerts`)

### 2. Install GitHub App

One-time setup: Install the "Google Cloud Build" GitHub App on your repository. This enables Cloud Build to access your GitHub repository.

### 3. Deploy

Push to the `main` branch → Cloud Build trigger automatically:
1. Builds container from `app/` directory
2. Pushes image to Artifact Registry
3. Deploys to Cloud Run with runtime Service Account

## Testing

After deployment, test the service:

```bash
# Get the Cloud Run service URL
SERVICE_URL=$(gcloud run services describe finops-controller \
  --region=us-central1 \
  --format="value(status.url)")

# Send a test event
curl -s -X POST $SERVICE_URL \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{"event_type":"budget.alert","foo":"bar"}'

# Check health endpoint
curl -s $SERVICE_URL/healthz
```

## Project Structure

```
.
├── infra/              # Terraform infrastructure code
│   ├── main.tf        # Main infrastructure resources
│   ├── variables.tf   # Input variables
│   ├── outputs.tf     # Output values
│   └── versions.tf    # Terraform version requirements
├── app/               # Python Flask application
│   ├── main.py       # Flask app with BigQuery ingestion
│   ├── requirements.txt
│   └── Dockerfile
├── cloudbuild.yaml    # Cloud Build configuration
└── README.md
```

## Resources Created

- **APIs Enabled**: Cloud Run, Artifact Registry, Cloud Build, IAM, BigQuery
- **Artifact Registry**: Docker repository for container images
- **Service Account**: Runtime SA with BigQuery dataEditor and user roles
- **BigQuery**: Dataset and alerts table with schema
- **Cloud Build Trigger**: GitHub push trigger for automatic deployments
- **Cloud Run Service**: Deployed service with runtime SA and environment variables

## Environment Variables

The Cloud Run service is configured with:
- `BQ_DATASET`: BigQuery dataset ID
- `BQ_ALERTS_TABLE`: BigQuery table ID
- `PORT`: Automatically set by Cloud Run (default: 8080)

## Security

- Cloud Run service is **not publicly accessible** (`--no-allow-unauthenticated`)
- Runtime Service Account has minimal permissions (BigQuery only)
- Cloud Build Service Account has necessary permissions for deployment

## Troubleshooting

- **Build fails**: Check Cloud Build logs in GCP Console
- **Deployment fails**: Verify Cloud Build SA has `roles/run.admin`
- **BigQuery errors**: Ensure runtime SA has BigQuery permissions
- **Authentication errors**: Use `gcloud auth print-identity-token` for testing
