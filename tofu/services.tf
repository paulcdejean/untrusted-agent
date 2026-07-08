# The project itself is created out of band:
#   gcloud projects create untrusted-agent-paul
#   gcloud billing projects link untrusted-agent-paul --billing-account=...
data "google_project" "agent" {
  project_id = local.workspace.project_id
}

resource "google_project_service" "services" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iap.googleapis.com",
  ])
  project            = local.workspace.project_id
  service            = each.value
  disable_on_destroy = false
}
