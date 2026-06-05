terraform {
  required_version = ">= 1.6.0"

  required_providers {
    clerk = {
      source  = "clerk/clerk"
      version = "~> 0.4"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }
}

provider "clerk" {
  # CLERK_SECRET_KEY read from env (populated by Vault agent sidecar at runtime).
  # Never pass the secret as a Terraform variable — it would land in state.
}

provider "vault" {
  address = var.vault_addr
  # Auth: Vault AppRole (role_id + secret_id injected by CI/CD, never stored here).
}
