resource "google_compute_instance" "agent" {
  project      = local.workspace.project_id
  name         = "untrusted-agent-${tofu.workspace}"
  zone         = local.workspace.zone
  machine_type = "e2-small"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  # No access_config block: the box has no external IP. Inbound is IAP-only,
  # outbound goes through Cloud NAT.
  network_interface {
    network = "default"
  }

  service_account {
    email  = google_service_account.agent.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = templatefile("${path.module}/templates/startup.sh.tftpl", {
      proxy_url      = google_cloudfunctions2_function.openrouter_proxy.url
      sidecar_source = file("${path.module}/templates/sidecar.mjs")
      models_json    = file("${path.module}/templates/models.json")
    })
  }

  depends_on = [google_compute_router_nat.agent]
}

output "ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.agent.name} --project ${local.workspace.project_id} --zone ${google_compute_instance.agent.zone} --tunnel-through-iap"
}
