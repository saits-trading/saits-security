# Example: onboard two tenants (acme-corp Shared, devshop-llc Private)
#
# Usage:
#   export CLERK_SECRET_KEY=$(vault kv get -field=clerk_secret_key kv/saitscloud/clerk/app)
#   terraform init
#   terraform apply

module "clerk" {
  source = "../../"

  vault_addr  = "https://vault.saits-sync.svc.cluster.local:8200"
  environment = "prod"
  clerk_domain = "clerk.saits.cloud"

  tenants = {
    "d3f1a2b4-0001-0000-0000-000000000001" = {
      name              = "Acme Corp"
      tier              = "shared"
      allowed_providers = ["google_oauth", "email_password"]
      admin_email       = "admin@acme-corp.example"
    }
    "d3f1a2b4-0002-0000-0000-000000000002" = {
      name              = "DevShop LLC"
      tier              = "private"
      allowed_providers = ["google_oauth", "github", "email_password"]
      admin_email       = "platform@devshop.example"
    }
  }

  google_oauth_vault_path = "saitscloud/clerk/google-oauth"
  github_oauth_vault_path = "saitscloud/clerk/github-oauth"
}

output "acme_org_id" {
  value = module.clerk.tenant_org_ids["d3f1a2b4-0001-0000-0000-000000000001"]
}
