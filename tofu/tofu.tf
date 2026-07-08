terraform {
  required_version = "1.12.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.39.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.8.0"
    }
    openrouter = {
      source  = "cloudopsworks/openrouter"
      version = "0.2.17"
    }
  }
  backend "s3" {
    profile                     = "cloudflare"
    bucket                      = "tofu"
    workspace_key_prefix        = "untrusted-agent"
    key                         = basename(abspath(path.module))
    use_lockfile                = true
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

# No default project: the ID comes from the name lookup in data.tf, and a
# provider config can't depend on a data source it itself reads. Every
# resource sets project explicitly instead.
provider "google" {
  region = local.workspace.region
}

# Authenticates with the OPENROUTER_API_KEY environment variable, which must
# hold an OpenRouter *provisioning* key (openrouter.ai/settings/keys). It only
# ever exists in the shell running tofu; the runtime key it mints is what
# lands in Secret Manager.
provider "openrouter" {}
