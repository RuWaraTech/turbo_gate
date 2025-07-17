# terraform {
#   backend "s3" {
#     bucket   = "turbogate-terraform-state"       # Must match your Hetzner bucket name
#     key      = "production/terraform.tfstate"    # State file path
#     endpoint = "https://turbogate-terraform-state.fsn1.hetzner.cloud" # Your bucket URL
#     region   = "eu-central-1"                    # Hetzner uses AWS-compatible regions
    
#     # Required for Hetzner (not AWS S3)
#     skip_credentials_validation = true
#     skip_region_validation      = true
#     skip_metadata_api_check     = true
#   }
# }

terraform {
  required_version = "~> 1.6.0"
  
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
  }
}