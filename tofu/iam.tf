# The proxy function's SA is the only principal that can read the key.
resource "google_secret_manager_secret_iam_member" "proxy_reads_key" {
  project   = local.workspace.project_id
  secret_id = google_secret_manager_secret.openrouter_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.proxy.email}"
}

# The agent VM may invoke the proxy — this IAM binding is the entire trust
# relationship between the untrusted box and the key-holding function.
resource "google_cloud_run_v2_service_iam_member" "agent_invokes_proxy" {
  project  = local.workspace.project_id
  location = local.workspace.region
  name     = google_cloudfunctions2_function.openrouter_proxy.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.agent.email}"
}

resource "google_project_iam_member" "agent_logging" {
  project = local.workspace.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

resource "google_project_iam_member" "agent_monitoring" {
  project = local.workspace.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Cloud Functions gen2 builds run as the compute default SA on new projects,
# which no longer gets this role automatically (GCP change of May 2024).
resource "google_project_iam_member" "compute_default_builds" {
  project    = local.workspace.project_id
  role       = "roles/cloudbuild.builds.builder"
  member     = "serviceAccount:${data.google_project.agent.number}-compute@developer.gserviceaccount.com"
  depends_on = [google_project_service.services]
}

# Human access to the VM: OS Login + IAP tunnel.
resource "google_project_iam_member" "admin_oslogin" {
  project = local.workspace.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "user:${local.workspace.admin_user}"
}

resource "google_project_iam_member" "admin_iap_tunnel" {
  project = local.workspace.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:${local.workspace.admin_user}"
}

resource "google_service_account_iam_member" "admin_uses_agent_sa" {
  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${local.workspace.admin_user}"
}
