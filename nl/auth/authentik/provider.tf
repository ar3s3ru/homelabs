terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }

    authentik = {
      source  = "goauthentik/authentik"
      version = "2024.12.0"
    }
  }
}

variable "authentik_token" {
  type        = string
  description = "Authentik token for Terraform provider - created manually"
  sensitive   = true
}

provider "random" {}

provider "authentik" {
  url   = "https://auth.nl.ar3s3ru.dev"
  token = var.authentik_token
}
