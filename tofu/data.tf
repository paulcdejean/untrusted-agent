# Project IDs are globally unique, so the ID behind "a project named
# untrusted-agent" depends on who created it. Names are per-account and
# freely chosen, so the workspace map carries the name and the ID is looked
# up here.
data "google_projects" "this" {
  filter = "name:${local.workspace.project_name} lifecycleState:ACTIVE"
}

data "google_project" "this" {
  project_id = one(data.google_projects.this.projects[*].project_id)
  lifecycle {
    precondition {
      condition     = length(data.google_projects.this.projects) == 1
      error_message = "Expected exactly one active project named ${local.workspace.project_name}, found ${length(data.google_projects.this.projects)}."
    }
  }
}

# Whoever runs tofu is the human admin — no email hardcoded in source.
data "google_client_openid_userinfo" "me" {}

locals {
  project_id = data.google_project.this.project_id
  admin_member = (
    endswith(data.google_client_openid_userinfo.me.email, "gserviceaccount.com")
    ? "serviceAccount:${data.google_client_openid_userinfo.me.email}"
    : "user:${data.google_client_openid_userinfo.me.email}"
  )
}
