# saits-security

Security primitives for saitsCloud. Sister-repo to `saits-sync` (central Redis state)
and `saits-observability` (Prom/Loki/Tempo/Grafana).

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

## Planned layout

Populated by follow-up PRs from crew6 / crew7. v0 ships docs only.

- `vault/` — Vault Helm chart values, PKI mount config, AppRole policies (crew6)
- `cilium/` — NetworkPolicy templates: default-deny + per-tenant allow + ClusterMesh hybrid back-channel (crew6)
- `falco/` — runtime rules with per-tenant violation routing → Alertmanager (crew6)
- `kyverno/` — admission policies: cosign image-signing, no-priv-esc, no-host-network, no-host-pid (crew4)
- `terraform/vault-bootstrap/` — AppRole + PKI mount Terraform (crew6)
- `terraform/clerk/` — per-tenant Clerk org provisioning, JWT template, OAuth social connections (crew7) **[live on main]**
- `siem/` — Elastic forwarder config + correlation rules (crew6)

## What does NOT live here

- Application authn/authz business logic — that's in service repos using `@saits-internal/sync` ClerkVerifier
- Prometheus/Loki/Tempo/Grafana — see `saits-observability`
- Redis ACL bootstrap — see `saits-sync` (Redis ACL users are state, not policy)

## Forbidden patterns

- Plaintext secrets anywhere in repo — `git-secrets` pre-commit + crew4 review-gate
- `default` Cilium policy that allows tenant→tenant traffic — admission-blocked
- Unsigned container images in production manifests — Kyverno blocks
- Vault root token in CI / agent env — only AppRole + short-TTL tokens
