output "jwt_template_id" {
  description = "Clerk JWT template ID for the saitscloud token (pass to sc-api as CLERK_JWT_TEMPLATE_ID)."
  value       = clerk_jwt_template.saitscloud.id
}

output "jwt_template_name" {
  description = "Clerk JWT template name (e.g. saitscloud-prod)."
  value       = clerk_jwt_template.saitscloud.name
}

output "google_oauth_app_id" {
  description = "Clerk internal ID of the Google OAuth application."
  value       = clerk_oauth_application.google.id
}

output "github_oauth_app_id" {
  description = "Clerk internal ID of the GitHub OAuth application."
  value       = clerk_oauth_application.github.id
}

output "tenant_org_ids" {
  description = "Map of tenant_id → Clerk organization ID for each provisioned tenant."
  value       = { for k, v in clerk_organization.tenant : k => v.id }
}

output "tenant_org_slugs" {
  description = "Map of tenant_id → Clerk organization slug."
  value       = { for k, v in clerk_organization.tenant : k => v.slug }
}
