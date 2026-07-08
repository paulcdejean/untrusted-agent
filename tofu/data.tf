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

locals {
  project_id = data.google_project.this.project_id
}
