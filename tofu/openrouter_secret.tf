# A dedicated runtime key for this workspace, minted through the OpenRouter
# management API (the provisioning key authenticating the provider never
# enters state; this child key does, marked sensitive — the provider has no
# ephemeral variant). Rotation:
#   tofu apply -replace=openrouter_api_key.agent
# which cascades: new key -> new secret version -> new function revision.
resource "openrouter_api_key" "agent" {
  name = "untrusted-agent-${tofu.workspace}"
}

resource "google_secret_manager_secret" "openrouter_api_key" {
  project   = local.project_id
  secret_id = "untrusted_agent-${tofu.workspace}-openrouter_api_key"
  replication {
    auto {}
  }
  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "openrouter_api_key" {
  secret                 = google_secret_manager_secret.openrouter_api_key.id
  secret_data_wo         = openrouter_api_key.agent.key
  secret_data_wo_version = 1
  lifecycle {
    # secret_data_wo changing is invisible to plans, so a rotated key has to
    # force this version to roll some other way: the key's id is a hash that
    # changes exactly when the key is replaced.
    replace_triggered_by = [openrouter_api_key.agent.id]
  }
}
