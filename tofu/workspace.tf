locals {
  workspace = local.workspaces[tofu.workspace]
  workspaces = {
    unstable = {
      project_id = "untrusted-agent-${tofu.workspace}"
      region     = "us-central1"
      zone       = "us-central1-a"
      admin_user = "paulcdejean@gmail.com"
    }
  }
}
