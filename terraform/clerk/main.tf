# saits-security/terraform/clerk
#
# Provisions:
#   - saits.cloud Clerk JWT template (canonical claims per saitsCloud_PLAN.md §7)
#   - Google + GitHub social connections (credentials from Vault)
#   - One Clerk organization per tenant (mapped to saits-sync tenant_id)
#
# What is NOT managed here:
#   - SAML/Enterprise IdP connections (provisioned manually via Clerk Dashboard;
#     saml_connection_id is referenced but not created here)
#   - User accounts (created at runtime via Clerk SDK)
#   - Vault PKI / Redis ACL (saits-sync + sibling Vault Helm module)

# ── Vault: fetch OAuth credentials (never pass as TF variables in plaintext) ──

data "vault_kv_secret_v2" "google_oauth" {
  mount = "kv"
  name  = var.google_oauth_vault_path
}

data "vault_kv_secret_v2" "github_oauth" {
  mount = "kv"
  name  = var.github_oauth_vault_path
}

# ── JWT template ──────────────────────────────────────────────────────────────
#
# Produces tokens with canonical saitsCloud schema fields (§7).
# OPA resolves `role` at request-time from the token + policy bundle;
# the Clerk org_id → tenant_id mapping is maintained in saits-sync.
#
# Clerk Handlebars context:
#   {{user.id}}              → Clerk user sub (becomes actor_id)
#   {{org.id}}               → Clerk org ID (becomes saits_org_id for mapping)
#   {{org.slug}}             → org slug (human-readable tenant name)
#   {{org.public_metadata.*}} → custom metadata set at org-provision time

resource "clerk_jwt_template" "saitscloud" {
  name              = "saitscloud-${var.environment}"
  token_lifetime    = var.jwt_token_lifetime_seconds
  allowed_clock_skew = 5

  claims = jsonencode({
    # Actor — unique Clerk user sub, used as actor_id in audit + RBAC.
    actor_id = "{{user.id}}"

    # Tenant binding — Clerk org ID; the control-plane maps this to saits-sync
    # tenant_id at provisioning time (stored in org.public_metadata.tenant_id).
    # Direct JWT claim avoids an extra lookup on every request.
    tenant_id = "{{org.public_metadata.tenant_id}}"

    # Tier — used for routing in sc-api (shared/private/hybrid).
    tenant_tier = "{{org.public_metadata.tier}}"

    # Subtenant chain — populated only for delegated sessions.
    # Empty string when not a subtenant context.
    subtenant_id = "{{org.public_metadata.subtenant_id}}"

    # Environment label — lets services reject staging tokens in prod.
    env = var.environment

    # Issuer-scoped audience — prevents token reuse across environments.
    aud = "saits.cloud/${var.environment}"
  })
}

# ── Google OAuth social connection ────────────────────────────────────────────

resource "clerk_oauth_application" "google" {
  provider_name = "oauth_google"
  client_id     = data.vault_kv_secret_v2.google_oauth.data["google_client_id"]
  client_secret = data.vault_kv_secret_v2.google_oauth.data["google_client_secret"]
  enabled       = true

  # Scopes needed for profile + email; openid is implicit via Clerk.
  scopes = ["email", "profile"]
}

# ── GitHub OAuth social connection ────────────────────────────────────────────

resource "clerk_oauth_application" "github" {
  provider_name = "oauth_github"
  client_id     = data.vault_kv_secret_v2.github_oauth.data["github_client_id"]
  client_secret = data.vault_kv_secret_v2.github_oauth.data["github_client_secret"]
  enabled       = true

  scopes = ["read:user", "user:email"]
}

# ── Per-tenant Clerk organizations ────────────────────────────────────────────
#
# One Clerk org per saits-sync tenant.  The org's public_metadata carries
# tenant_id + tier so the JWT template can embed them without a runtime lookup.

resource "clerk_organization" "tenant" {
  for_each = var.tenants

  name = each.value.name
  slug = replace(lower(each.value.name), "/[^a-z0-9-]/", "-")

  public_metadata = jsonencode({
    tenant_id    = each.key
    tier         = each.value.tier
    subtenant_id = ""
    environment  = var.environment
  })

  private_metadata = jsonencode({
    admin_email = each.value.admin_email
  })

  max_allowed_memberships = each.value.tier == "shared" ? 5 : 500
}

# ── Vault: store Clerk org → tenant_id mapping ────────────────────────────────
#
# Written to Vault so sc-api can validate JWT tenant_id claims without calling
# the Clerk API on every request.  Key: clerk_org_id → saits tenant_id.

resource "vault_kv_secret_v2" "clerk_org_mapping" {
  for_each = var.tenants

  mount               = "kv"
  name                = "saitscloud/clerk/org-mapping/${clerk_organization.tenant[each.key].id}"
  delete_all_versions = false

  data_json = jsonencode({
    tenant_id   = each.key
    tenant_name = each.value.name
    tier        = each.value.tier
    org_id      = clerk_organization.tenant[each.key].id
    environment = var.environment
  })
}
