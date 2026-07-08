# Custom VPC instead of the default network: we need a dual-stack subnet for
# IPv6 egress, and we shed the default network's allow-from-anywhere rules.
resource "google_compute_network" "agent" {
  project                 = local.workspace.project_id
  name                    = "untrusted-agent-${tofu.workspace}"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.services]
}

# Egress works like an AWS egress-only internet gateway: the VM gets an
# external IPv6 address (free, unlike Cloud NAT), and the VPC's implied
# deny-ingress means nothing can dial in. IPv4 stays internal-only.
resource "google_compute_subnetwork" "agent" {
  project          = local.workspace.project_id
  name             = "untrusted-agent-${tofu.workspace}"
  region           = local.workspace.region
  network          = google_compute_network.agent.id
  ip_cidr_range    = "10.0.0.0/24"
  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "EXTERNAL"
}

# SSH reaches the VM only through IAP's tunnel range (over internal IPv4).
resource "google_compute_firewall" "iap_ssh" {
  project                 = local.workspace.project_id
  name                    = "untrusted-agent-${tofu.workspace}-iap-ssh"
  network                 = google_compute_network.agent.id
  source_ranges           = ["35.235.240.0/20"]
  target_service_accounts = [google_service_account.agent.email]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
