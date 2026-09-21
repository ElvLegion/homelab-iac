# Security Decisions

This repository is a homelab and portfolio project rather than a production environment. Security scanning is used to identify meaningful risks, but findings are evaluated against the intended architecture rather than treated as requirements for a perfect scanner score.

## Checkov Exceptions

### Azure Key Vault public endpoint

Checkov findings:

- `CKV_AZURE_189`
- `CKV_AZURE_109`
- `CKV2_AZURE_32`

The bootstrap Key Vault currently uses its public Azure endpoint rather than a private endpoint.

Access to secrets is still controlled through Azure RBAC. The utility VM retrieves the Tailscale bootstrap credential using a user-assigned managed identity with the `Key Vault Secrets User` role.

A private endpoint was not implemented because it would add additional private DNS and network dependencies to the first-boot bootstrap path.

This may be revisited if the environment grows beyond the current homelab scope.

### Key Vault purge protection

Checkov findings:

- `CKV_AZURE_110`
- `CKV_AZURE_42`

Soft delete is enabled.

Purge protection is intentionally disabled because the Key Vault is part of rebuildable homelab infrastructure. Enabling purge protection would make complete teardown and recreation significantly more difficult.

Production environments should generally enable purge protection for critical secrets.

### Public HTTP access

Checkov finding:

- `CKV_AZURE_160`

TCP port 80 is intentionally exposed for the public Caddy endpoint.

Caddy handles public web traffic and HTTPS redirection for:

`status.elvishlegion.com`

SSH is not exposed publicly.

### Public IP address

Checkov finding:

- `CKV_AZURE_119`

The utility VM intentionally has a public IP because it hosts the public Caddy endpoint.

Administrative access does not use the public IP. SSH is restricted to the Tailscale interface by UFW and is not permitted through the Azure NSG.

### Virtual machine extension capability

Checkov finding:

- `CKV_AZURE_50`

VM extension capability is intentionally retained.

Azure management functionality such as Run Command provides a useful break-glass administration path if Tailscale or SSH becomes unavailable. Future Azure Monitor or management integrations may also require extension support.

## Verified Controls

The current environment has been tested with the following controls:

- SSH key authentication only
- password authentication disabled
- no public SSH NSG rule
- UFW permits SSH only through `tailscale0`
- Secure Boot enabled
- virtual TPM enabled
- Encryption at Host enabled
- pinned Ubuntu image version
- Tailscale bootstrap through Azure managed identity and Key Vault
- Grafana bound only to loopback
- Gatus bound only to loopback
- public ingress limited to Caddy on TCP 80/443
- Docker images pinned by immutable digest
- container log rotation configured
- Terraform reports no infrastructure drift
- Ansible bootstrap is idempotent
- `ansible-lint` passes the production profile
- `yamllint` passes
- GitHub Actions automatically runs Checkov, Terraform validation, `ansible-lint`, and `yamllint` on pull requests and pushes to `main`

## Future Improvements

Potential future security improvements include:

- Azure Key Vault private endpoint and private DNS
- remote Terraform state in Azure Storage
- GitHub Actions using Azure OIDC instead of stored credentials
- Tailscale workload identity federation
