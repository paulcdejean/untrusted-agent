locals {
  workspace = local.workspaces[tofu.workspace]
  workspaces = {
    # Both workspaces share one project (looked up by display name, not ID —
    # IDs are globally unique, so whoever deploys this ends up with a
    # different one; data.tf resolves the name). Every resource is namespaced
    # by workspace, and nothing project-level is shared between them.
    unstable = {
      project_name = "untrusted-agent"
      region       = "us-central1"
      zone         = "us-central1-a"
    }
    prod = {
      project_name = "untrusted-agent"
      region       = "us-central1"
      zone         = "us-central1-a"
    }
  }
}
