resource "google_storage_bucket" "function_source" {
  project                     = local.workspace.project_id
  name                        = "${local.workspace.project_id}-${tofu.workspace}-function-source"
  location                    = local.workspace.region
  uniform_bucket_level_access = true
  force_destroy               = true
  depends_on                  = [google_project_service.services]
}

data "archive_file" "proxy_source" {
  type        = "zip"
  source_dir  = "${path.module}/../proxy"
  output_path = "${path.module}/dist/openrouter-proxy.zip"
  excludes    = ["node_modules"]
}

resource "google_storage_bucket_object" "proxy_source" {
  bucket = google_storage_bucket.function_source.name
  name   = "openrouter-proxy-${data.archive_file.proxy_source.output_md5}.zip"
  source = data.archive_file.proxy_source.output_path
}

resource "google_cloudfunctions2_function" "openrouter_proxy" {
  project  = local.workspace.project_id
  name     = "untrusted-agent-proxy-${tofu.workspace}"
  location = local.workspace.region

  build_config {
    runtime     = "nodejs22"
    entry_point = "proxy"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.proxy_source.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.proxy.email
    available_memory      = "256M"
    max_instance_count    = 3
    # Agentic responses stream for a long time; give them the gen2 HTTP maximum.
    timeout_seconds  = 3600
    ingress_settings = "ALLOW_ALL"
    secret_environment_variables {
      key        = "OPENROUTER_API_KEY"
      project_id = local.workspace.project_id
      secret     = google_secret_manager_secret.openrouter_api_key.secret_id
      version    = "latest"
    }
  }

  depends_on = [
    google_secret_manager_secret_version.openrouter_api_key,
    google_secret_manager_secret_iam_member.proxy_reads_key,
    google_project_iam_member.compute_default_builds,
  ]
}

output "proxy_url" {
  value = google_cloudfunctions2_function.openrouter_proxy.url
}
