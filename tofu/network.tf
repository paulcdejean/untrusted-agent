# The VM has no external IP. Cloud NAT provides outbound-only internet
# (apt, npm, and HTTPS to the proxy's run.app URL).
resource "google_compute_router" "agent" {
  project    = local.workspace.project_id
  name       = "untrusted-agent-${tofu.workspace}"
  region     = local.workspace.region
  network    = "default"
  depends_on = [google_project_service.services]
}

resource "google_compute_router_nat" "agent" {
  project                            = local.workspace.project_id
  name                               = "untrusted-agent-${tofu.workspace}"
  region                             = local.workspace.region
  router                             = google_compute_router.agent.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# SSH reaches the VM only through IAP's tunnel range.
resource "google_compute_firewall" "iap_ssh" {
  project                 = local.workspace.project_id
  name                    = "untrusted-agent-${tofu.workspace}-iap-ssh"
  network                 = "default"
  source_ranges           = ["35.235.240.0/20"]
  target_service_accounts = [google_service_account.agent.email]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  depends_on = [google_project_service.services]
}
