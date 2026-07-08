# Holds the only secret access in the system: reads openrouter_api_key at runtime.
resource "google_service_account" "proxy" {
  project      = local.project_id
  account_id   = "proxy-${tofu.workspace}"
  display_name = "Untrusted agent proxy function"
  depends_on   = [google_project_service.services]
}

# Runs the proxy function's builds. The compute default SA would work (with
# roles/cloudbuild.builds.builder, no longer automatic since May 2024) but is
# shared project-wide, and each workspace must own its own IAM members.
resource "google_service_account" "build" {
  project      = local.project_id
  account_id   = "build-${tofu.workspace}"
  display_name = "Untrusted agent function build"
  depends_on   = [google_project_service.services]
}

# Identity of the agent VM. Deliberately near-powerless: it can invoke the
# proxy and write its own logs/metrics, nothing else. It can never read the
# OpenRouter key.
resource "google_service_account" "agent" {
  project      = local.project_id
  account_id   = "agent-${tofu.workspace}"
  display_name = "Untrusted agent VM"
  depends_on   = [google_project_service.services]
}
