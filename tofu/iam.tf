# The proxy function's SA is the only principal that can read the key.
resource "google_secret_manager_secret_iam_member" "proxy_reads_key" {
  project   = local.project_id
  secret_id = google_secret_manager_secret.openrouter_api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.proxy.email}"
}

# The agent VM may invoke the proxy — this IAM binding is the entire trust
# relationship between the untrusted box and the key-holding function.
resource "google_cloud_run_v2_service_iam_member" "agent_invokes_proxy" {
  project  = local.project_id
  location = local.workspace.region
  name     = google_cloudfunctions2_function.openrouter_proxy.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.agent.email}"
}

resource "google_project_iam_member" "agent_logging" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

resource "google_project_iam_member" "agent_monitoring" {
  project = local.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.agent.email}"
}

# Function builds run as a per-workspace SA (see proxy_function.tf) so that
# workspaces sharing one project never share a binding — with the compute
# default SA, both workspaces' states would own the same member.
resource "google_project_iam_member" "build_builds" {
  project = local.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.build.email}"
}

# A build kicked off seconds after the grant above loses the IAM propagation
# race (observed on both workspaces: "Access to bucket gcf-v2-sources-*
# denied"). Sleeping only on grant creation keeps steady-state applies free.
resource "time_sleep" "build_iam_propagation" {
  create_duration = "20s"
  triggers = {
    grant = google_project_iam_member.build_builds.id
  }
}

# Human access to the VM: OS Login + IAP tunnel, granted on the instance
# rather than the project — per-workspace, and the smallest scope that works.
# Instance IAM dies with the instance, and this VM is replaced routinely, so
# the grants must be replaced in the same apply.
resource "google_compute_instance_iam_member" "admin_oslogin" {
  project       = local.project_id
  zone          = google_compute_instance.agent.zone
  instance_name = google_compute_instance.agent.name
  role          = "roles/compute.osAdminLogin"
  member        = local.admin_member
  lifecycle {
    replace_triggered_by = [google_compute_instance.agent.id]
  }
}

resource "google_iap_tunnel_instance_iam_member" "admin_iap_tunnel" {
  project  = local.project_id
  zone     = google_compute_instance.agent.zone
  instance = google_compute_instance.agent.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = local.admin_member
  lifecycle {
    replace_triggered_by = [google_compute_instance.agent.id]
  }
}

resource "google_service_account_iam_member" "admin_uses_agent_sa" {
  service_account_id = google_service_account.agent.name
  role               = "roles/iam.serviceAccountUser"
  member             = local.admin_member
}
