# terraform/clerk

Provisions per-tenant Clerk organizations, the saitscloud JWT template, and
Google/GitHub social connections. All OAuth credentials are read from Vault at
plan time — never stored as Terraform variables or in state as plaintext.

## What this manages

| Resource | Description |
|---|---|
| `clerk_jwt_template.saitscloud` | Custom JWT with `tenant_id`, `actor_id`, `tenant_tier`, `env`, `aud` |
| `clerk_oauth_application.google` | Google OAuth2 social connection (creds from Vault) |
| `clerk_oauth_application.github` | GitHub OAuth2 social connection (creds from Vault) |
| `clerk_organization.tenant[*]` | One Clerk org per saits-sync tenant; `public_metadata` carries canonical fields |
| `vault_kv_secret_v2.clerk_org_mapping[*]` | Clerk org_id → tenant_id mapping in Vault for fast JWT validation |

## What this does NOT manage

- SAML/Enterprise IdP connections — configured via Clerk Dashboard, `saml_connection_id` referenced only
- Vault PKI and mTLS — see `../vault/`
- Redis ACL users — see `saits-sync` control-plane scripts

## Usage

```bash
# Credentials injected by CI/Vault agent — never passed as TF variables:
export CLERK_SECRET_KEY=$(vault kv get -field=clerk_secret_key kv/saitscloud/clerk/app)

cd terraform/clerk/examples/tenant-onboarding
terraform init
terraform plan -out=tf.plan
terraform apply tf.plan
```

## Adding a tenant

Extend the `tenants` map in your root module:

```hcl
tenants = {
  "<new-tenant-uuid>" = {
    name              = "New Tenant Inc."
    tier              = "private"        # shared | private | hybrid
    allowed_providers = ["google_oauth", "email_password"]
    admin_email       = "admin@newtenant.example"
  }
}
```

`terraform apply` creates the Clerk org and writes the org → tenant_id mapping
to Vault. The JWT template and social connections are shared across all tenants.

## JWT claims reference

| Claim | Source | Purpose |
|---|---|---|
| `tenant_id` | `org.public_metadata.tenant_id` | Primary partition key — scopes all Redis/OPA/audit ops |
| `actor_id` | `user.id` | Audit + RBAC identity |
| `tenant_tier` | `org.public_metadata.tier` | Routing in sc-api (shared/private/hybrid) |
| `subtenant_id` | `org.public_metadata.subtenant_id` | Populated for delegated subtenant sessions |
| `env` | Terraform var | Prevents staging tokens from being used in prod |
| `aud` | `saits.cloud/<env>` | Token audience scoping |

`role` is **NOT** in the JWT — it is resolved at request-time by OPA from the
token claims + policy bundle, never minted by Clerk.
