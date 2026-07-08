locals {
  workspace = local.workspaces[tofu.workspace]
  workspaces = {
    unstable = {
      # The project's display name, not its ID — IDs are globally unique, so
      # whoever deploys this ends up with a different one. data.tf resolves
      # the name to the actual ID.
      project_name = "untrusted-agent"
      region     = "us-central1"
      zone       = "us-central1-a"
      admin_user = "paulcdejean@gmail.com"
    }
  }
}
