# saits-security — Crew Instructions

Sister-repo to `saits-sync` and `saits-observability`. Same conventions, different domain.

## Domain ownership

| crew | scope |
|---|---|
| crew4 (QA / security-review) | review-gate on ALL PRs — no merge without crew4 explicit sign-off, especially on Cilium NetworkPolicy + Kyverno + Vault policy changes |
| crew6 (DevOps) | Vault Helm + AppRole bootstrap, Cilium ClusterMesh, Falco DaemonSet, Elastic SIEM forwarder |
| crew7 (Agentics/Fintech) | Clerk org Terraform, SPIFFE/SPIRE M2M identity (if/when adopted) |

## PR review gates

Every PR must pass these before crew4 merges:

1. **No plaintext secrets** — `git-secrets` scan + manual grep for `BEGIN PRIVATE KEY`, `xoxb-`, `sk_live_`, `hvs.`, `ghp_`, `github_pat_`, `AKIA`, `ASIA`, `sk-ant-`, Vault tokens, Discord bot tokens, Anthropic OAuth tokens
2. **NetworkPolicy default-deny** — any new namespace/tenant must inherit default-deny; explicit allow rules need crew4 + crew6 dual-review
3. **Kyverno policy = enforce mode** — `audit` mode allowed for new policies during burn-in (max 1 week), then must flip to `enforce` or be removed
4. **Vault policy least-privilege** — no `*` paths, no `sudo` capability, no `root` token issuance from CI/AppRole
5. **No --insecure / --skip-verify flags** in mTLS or cosign verification configs — review-blocked

## What does NOT belong here

- Application code that USES these primitives — service repos
- Observability for security events — those alerts live in `saits-observability/alerts/` and consume Falco/Kyverno metrics
- Redis ACL user provisioning — that's in `saits-sync` (state, not policy)

## Hard mandates (operator-set)

1. **No secrets via Discord** — even "internal" channels leak via history/export. Read from Vault at incident-time, never paste secrets into a channel.
2. **Vault is single source of truth for credentials** — no .env duplication of Vault-managed secrets in any service repo.
3. **All M2M traffic must be mTLS** — plain-HTTP between services across tenant boundaries is a P0 incident.
4. **All container images must be cosign-signed** — Kyverno verifies at admission. Bypass surfaces that must NEVER appear in a PR: `--insecure-registry`, unsigned digest pin, `verifyImages.required: false` policy escape, `verifyImages` rule excluded from a namespace.

## Coordination with sibling repos

- `saits-sync` schema changes that affect tenant ACL → cross-reference issue here for review
- `saits-observability` Grafana datasource configs reading from Loki → ensure `X-Scope-OrgID` enforcement matches tenant-isolation guarantees here
