# saits-security

Security primitives for saitsCloud. Sister-repo to `saits-sync` (central Redis state)
and `saits-observability` (Prom/Loki/Tempo/Grafana).

> Note: the repo name has a trailing `-` because `saits-security` was taken at create-time.
> Don't rename — the URL is baked into Helm chart sources and Argo apps already.

## Scope

| Layer | Tool | Purpose |
|---|---|---|
| Secret store | HashiCorp Vault | KV-v2 for app secrets, PKI for mTLS, AppRole for crew/agents |
| Identity (humans) | Clerk OIDC | per-tenant org, JWT carries `saits_tenant_id` |
| Identity (M2M) | Vault PKI + SPIFFE | mTLS sender-constrained, per-service identity |
| Network isolation | Cilium NetworkPolicy | default-deny + per-tenant allow, ClusterMesh for hybrid back-channel |
| Runtime security | Falco | syscall-level intrusion detection |
| Admission control | Kyverno + cosign | image-signature-required, no-priv-esc, no-host-network |
| SIEM | Elastic | log forwarder + correlation rules (mirrors operator DevOps blueprint) |

## Architecture

```
                  ┌──────────────────────────────────────┐
                  │  Clerk (humans)         Vault (M2M)  │
                  │       │                     │        │
                  │       ▼                     ▼        │
                  │  JWT(saits_tenant_id)   mTLS cert    │
                  └──────────┬──────────────────┬───────┘
                             │                  │
                             ▼                  ▼
                  ┌──────────────────────────────────────┐
                  │  Ingress (HAProxy / Envoy)           │
                  │  - DPoP proof-of-possession check    │
                  │  - canonical X-Tenant-Id derivation  │
                  └──────────┬───────────────────────────┘
                             │
                             ▼  (Cilium NetworkPolicy: tenant→tenant DENY)
                  ┌──────────────────────────────────────┐
                  │  per-tenant workloads                │
                  │  ┌────────┐    ┌────────┐            │
                  │  │tenant-A│    │tenant-B│ ← Falco    │
                  │  └────────┘    └────────┘            │
                  └──────────────────────────────────────┘
```

## What lives here

- `vault/` — Vault Helm chart values, PKI mount config, AppRole policies
- `cilium/` — NetworkPolicy templates (default-deny + per-tenant allow + ClusterMesh hybrid back-channel)
- `falco/` — runtime rules (per-tenant violation routing → Alertmanager)
- `kyverno/` — admission policies (cosign image-signing, no-priv-esc, no-host-network, no-host-pid)
- `terraform/vault-bootstrap/` — AppRole + PKI mount Terraform
- `terraform/clerk-orgs/` — per-tenant Clerk org provisioning (matches Grafana org in observability)
- `siem/` — Elastic forwarder config + correlation rules

## What does NOT live here

- Application authn/authz business logic — that's in service repos using `@saits-internal/sync` ClerkVerifier
- Prometheus/Loki/Tempo/Grafana — see `saits-observability`
- Redis ACL bootstrap — see `saits-sync` (Redis ACL users are state, not policy)

## Forbidden patterns

- Plaintext secrets anywhere in repo — `git-secrets` pre-commit + crew4 review-gate
- `default` Cilium policy that allows tenant→tenant traffic — admission-blocked
- Unsigned container images in production manifests — Kyverno blocks
- Vault root token in CI / agent env — only AppRole + short-TTL tokens
