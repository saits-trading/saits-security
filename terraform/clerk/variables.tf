variable "vault_addr" {
  description = "Vault cluster address (e.g. https://vault.saits-sync.svc.cluster.local:8200)."
  type        = string
}

variable "environment" {
  description = "Deployment environment: dev | staging | prod."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "clerk_domain" {
  description = "Clerk frontend API domain (e.g. clerk.saits.cloud or accounts.saits.cloud)."
  type        = string
  default     = "clerk.saits.cloud"
}

# ── Per-tenant org provisioning ───────────────────────────────────────────────

variable "tenants" {
  description = <<-EOT
    Map of tenant_id → tenant config. tenant_id must match the UUID stored in
    saits-sync (tenant:<id>:tenant RedisJSON doc).

    allowed_providers controls which social connections the tenant's users can
    use. Restricting to google_oauth only is common for enterprise SAML tenants
    that want a single IdP.

    saml_connection_id is optional — only set for Enterprise tenants that have
    already configured a SAML IdP via Clerk Dashboard + separately provisioned
    the connection.
  EOT

  type = map(object({
    name              = string
    tier              = string # shared | private | hybrid
    allowed_providers = list(string) # google_oauth | github | microsoft | email_password | saml
    saml_connection_id = optional(string)
    admin_email       = string
  }))
  default = {}
}

# ── JWT template ──────────────────────────────────────────────────────────────

variable "jwt_token_lifetime_seconds" {
  description = "JWT access-token lifetime in seconds. Max 30 days; default 1h."
  type        = number
  default     = 3600
  validation {
    condition     = var.jwt_token_lifetime_seconds >= 60 && var.jwt_token_lifetime_seconds <= 2592000
    error_message = "jwt_token_lifetime_seconds must be between 60 (1 min) and 2592000 (30 days)."
  }
}

# ── Social connection OAuth credentials (read from Vault, not passed in-clear) ─

variable "google_oauth_vault_path" {
  description = "Vault KV path holding google_client_id + google_client_secret for OAuth2 social connection."
  type        = string
  default     = "saitscloud/clerk/google-oauth"
}

variable "github_oauth_vault_path" {
  description = "Vault KV path for GitHub OAuth2 social connection credentials."
  type        = string
  default     = "saitscloud/clerk/github-oauth"
}
