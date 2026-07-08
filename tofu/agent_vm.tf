locals {
  agent_machine_type = "e2-small"
  bun_version        = "1.3.14"
  agent_startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    # The run.app service URI, not .url: the cloudfunctions.net form carries
    # the function name as a path, which proxied request paths must not clobber.
    proxy_url      = google_cloudfunctions2_function.openrouter_proxy.service_config[0].uri
    bun_version    = local.bun_version
    sidecar_source = file("${path.module}/templates/sidecar.mjs")
    models_json    = file("${path.module}/templates/models.json")
    settings_json  = file("${path.module}/templates/settings.json")
  })
}

# The startup script only runs at boot and seeds /etc/skel, so in-place
# metadata updates never reach an already-provisioned box. Any change to the
# script (or the files templated into it) must recreate the VM instead.
resource "terraform_data" "agent_startup_script" {
  triggers_replace = local.agent_startup_script
}

# GCE only allows machine_type, service_account, and network changes on a
# stopped instance (allow_stopping_for_update). The box is disposable, so
# replace it instead of stop-modify-starting it.
resource "terraform_data" "agent_immutables" {
  triggers_replace = {
    machine_type    = local.agent_machine_type
    subnetwork      = google_compute_subnetwork.agent.id
    service_account = google_service_account.agent.email
  }
}

resource "google_compute_instance" "agent" {
  project      = local.workspace.project_id
  name         = "untrusted-agent-${tofu.workspace}"
  zone         = local.workspace.zone
  machine_type = local.agent_machine_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
      size  = 20
    }
  }

  # No access_config block: no external IPv4, so nothing can dial in and
  # SSH is IAP-only. Outbound rides the free external IPv6 (egress-only,
  # since the VPC has no ingress rules for it).
  network_interface {
    subnetwork = google_compute_subnetwork.agent.id
    stack_type = "IPV4_IPV6"
    ipv6_access_config {
      network_tier = "PREMIUM"
    }
  }

  service_account {
    email  = google_service_account.agent.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = local.agent_startup_script
  }

  lifecycle {
    replace_triggered_by = [
      terraform_data.agent_startup_script,
      terraform_data.agent_immutables,
    ]
  }
}

output "ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.agent.name} --project ${local.workspace.project_id} --zone ${google_compute_instance.agent.zone} --tunnel-through-iap"
}
