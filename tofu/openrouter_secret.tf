# The real key is added out of band and never touches state:
#   echo -n "sk-or-..." | gcloud secrets versions add \
#     untrusted_agent-<workspace>-openrouter_api_key \
#     --project untrusted-agent --data-file=-
# The proxy function reads version "latest", so the placeholder version
# below only exists to create the secret; adding a real version supersedes it.
resource "google_secret_manager_secret" "openrouter_api_key" {
  project   = local.workspace.project_id
  secret_id = "untrusted_agent-${tofu.workspace}-openrouter_api_key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "openrouter_api_key" {
  secret                 = google_secret_manager_secret.openrouter_api_key.id
  enabled                = true
  secret_data_wo         = "not_the_key"
  secret_data_wo_version = 0
  lifecycle {
    ignore_changes = [
      # We want to disable the placeholder version after we create the proper secret.
      enabled
    ]
  }
}
