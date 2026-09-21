# Homelab Infrastructure as Code

[![Infrastructure CI](https://github.com/ElvLegion/homelab-iac/actions/workflows/ci.yml/badge.svg)](https://github.com/ElvLegion/homelab-iac/actions/workflows/ci.yml)

Infrastructure-as-Code project for managing the Azure-based management and monitoring layer of a hybrid homelab.

The project uses Terraform, cloud-init, Azure managed identities, Azure Key Vault, Tailscale, Ansible, Docker Compose, Caddy, Gatus, and Grafana.

The goal is to make the management infrastructure reproducible while keeping application workloads on the systems where they make the most sense.

## Architecture

```text
                         Azure
                           |
                   vm-hmlb-util
                   Ubuntu 26.04
                           |
          +----------------+----------------+
          |                |                |
        Caddy            Gatus           Grafana
      public HTTPS     status checks    private/admin
          |                |                |
          +----------------+----------------+
                           |
                       Tailscale
                           |
               +-----------+-----------+
               |                       |
           minecraft                media-vps
            On-Prem                Interserver
               |                       |
               +------ Azure Arc ------+
```

`vm-hmlb-util` is the Azure utility VM managed by this repository.

The `minecraft` and `media-vps` hosts are externally managed systems. They are monitored from the utility VM and connected to Azure Arc, but this repository does not currently provision those hosts or their Arc agents.

## What This Project Uses

- **Terraform** - provisions Azure infrastructure
- **cloud-init** - performs first-boot Tailscale enrollment
- **Azure Managed Identity** - authenticates the VM to Azure without embedded Azure credentials
- **Azure Key Vault** - stores the Tailscale bootstrap credential
- **Ansible** - configures and maintains the Linux utility VM
- **Docker Compose** - deploys the monitoring stack
- **Tailscale** - private management network
- **Caddy** - public HTTPS reverse proxy
- **Gatus** - lightweight service and availability monitoring
- **Grafana** - private monitoring and visualization interface
- **Azure Arc** - connects external Linux systems to Azure
- **GitHub** - source control and off-site copy of the infrastructure code

## Repository Layout

```text
homelab-iac/
├── ansible/
│   ├── bootstrap.yml
│   ├── maintenance.yml
│   ├── monitoring.yml
│   ├── inventory.yml
│   ├── requirements.yml
│   └── files/
│       └── monitoring/
│           ├── compose.yml
│           ├── caddy/
│           │   └── Caddyfile
│           └── gatus/
│               └── config.yaml
│
└── terraform/
    └── azure/
        ├── bootstrap-secrets.tf
        ├── cloud-init.yaml.tftpl
        ├── versions.tf
        ├── providers.tf
        ├── variables.tf
        ├── locals.tf
        ├── resource-group.tf
        ├── network.tf
        ├── network-interface.tf
        ├── vm.tf
        └── outputs.tf
```

## Azure Infrastructure

Terraform currently provisions:

- Azure resource group
- Virtual network and subnet
- Network security group
- Static public IP
- Network interface
- Ubuntu 26.04 utility VM
- System-assigned managed identity
- User-assigned bootstrap managed identity
- Azure Key Vault
- Key Vault RBAC assignment for the bootstrap identity

The utility VM is configured with:

- pinned Ubuntu image version
- SSH public-key authentication
- password authentication disabled
- Secure Boot
- virtual TPM
- Encryption at Host
- boot diagnostics
- cloud-init bootstrap configuration

## First-Boot Bootstrap

The utility VM does not depend on Ansible for its initial management connection.

During first boot:

```text
Terraform
    |
    v
Azure VM created
    |
    v
cloud-init
    |
    v
User-assigned managed identity
    |
    v
Azure Key Vault
    |
    v
Tailscale bootstrap credential
    |
    v
VM joins Tailscale
    |
    v
SSH and Ansible become available
```

This avoids the bootstrap problem where Ansible would need SSH access before the private management network existed.

The Tailscale credential is not stored in the Terraform configuration or passed directly on the command line. The VM retrieves it from Key Vault using its managed identity.

The current bootstrap process uses a one-time Tailscale authentication key. A fresh unused key must be stored in Key Vault before a later VM replacement if the previous key has already been consumed.

## Ansible Configuration

After the VM joins Tailscale, Ansible configures the host.

`bootstrap.yml` manages:

- base Linux packages
- Docker Engine
- Docker Compose
- signed Docker apt repository
- signed Tailscale apt repository
- Tailscale service
- unattended security updates
- UFW
- Tailscale-only SSH access
- public HTTP/HTTPS firewall rules

The bootstrap playbook is idempotent. A second run should normally complete with:

```text
changed=0
failed=0
```

## Security Model

SSH is not exposed through the Azure NSG.

Administrative access follows:

```text
Workstation
    |
 Tailscale
    |
 SSH / Ansible
    |
vm-hmlb-util
```

The host firewall permits:

```text
SSH       TCP/22   tailscale0 only
HTTP      TCP/80   public
HTTPS     TCP/443  public
```

Grafana and Gatus are not directly exposed to the Internet.

Their Docker bindings are:

```text
Grafana   127.0.0.1:3000
Gatus     127.0.0.1:8080
```

Caddy is the only monitoring container with public HTTP/HTTPS bindings.

UDP 443 is not published on the host.

SSH private keys, Terraform variable files, Terraform state, and authentication secrets are excluded from Git.

Membership in the Docker group should be treated as root-equivalent access to the host.

## Monitoring Stack

### Gatus

Gatus currently performs availability checks for services including:

- Jellyfin
- Minecraft infrastructure
- Media VPS infrastructure

The public status page is available at:

```text
https://status.elvishlegion.com
```

### Grafana

Grafana is deployed privately on:

```text
127.0.0.1:3000
```

It can be accessed over an SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 vm-hmlb-util
```

Then browse to:

```text
http://127.0.0.1:3000
```

### Container Hardening

Monitoring images are pinned by immutable image digest.

Docker JSON logs are rotated with:

```text
max-size: 10m
max-file: 3
```

The Ansible monitoring playbook verifies Gatus and Grafana health after deployment.

Changes to the Caddy configuration are validated before Caddy is reloaded.

## Terraform Usage

Terraform is currently run locally.

From PowerShell:

```powershell
$env:TF_VAR_subscription_id = (az account show --query id -o tsv).Trim()
$env:TF_VAR_admin_ssh_public_key = (Get-Content "$env:USERPROFILE\.ssh\hmlb_azure.pub" -Raw).Trim()

terraform init
terraform validate
terraform plan
terraform apply
```

Encryption at Host must be enabled for the Azure subscription before deploying the VM:

```powershell
az feature register --namespace Microsoft.Compute --name EncryptionAtHost
az provider register --namespace Microsoft.Compute
```

The provider currently uses local Terraform state. Remote state is planned.

## Ansible Usage

Ansible is run from Ubuntu under WSL.

Install required collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

Test connectivity:

```bash
ansible all -i inventory.yml -m ping
```

Bootstrap the server:

```bash
ansible-playbook -i inventory.yml bootstrap.yml
```

Deploy the monitoring stack:

```bash
ansible-playbook -i inventory.yml monitoring.yml
```

Apply operating-system updates:

```bash
ansible-playbook -i inventory.yml maintenance.yml
```

The maintenance playbook installs updates but does not reboot the VM automatically unless explicitly requested.

To permit a maintenance reboot:

```bash
ansible-playbook -i inventory.yml maintenance.yml -e maintenance_reboot=true
```

## Rebuild Process

The utility VM rebuild path has been tested end-to-end.

A replacement follows:

```text
Terraform
    |
    v
Azure infrastructure / VM
    |
    v
cloud-init
    |
    v
Tailscale enrollment
    |
    v
SSH connectivity
    |
    v
Ansible bootstrap
    |
    v
Docker + host configuration
    |
    v
Ansible monitoring deployment
    |
    v
Caddy + Gatus + Grafana
```

The process has been tested by destroying and recreating `vm-hmlb-util`, allowing the new VM to join Tailscale automatically before Ansible was run.

Application data and persistent backups remain separate from infrastructure code.

## Azure Arc

The following external hosts are connected to Azure Arc:

- `minecraft`
- `media-vps`

Arc enrollment is currently managed outside this repository.

The repository should therefore not be interpreted as a complete rebuild mechanism for those external hosts.

## Current Limitations

- Terraform state is stored locally
- Tailscale bootstrap currently depends on a valid unused authentication key in Key Vault
- Azure Arc enrollment is not codified here
- Monitoring application data is stored in Docker volumes rather than managed by Terraform
- The externally managed Minecraft and media hosts are outside the Terraform lifecycle

## Roadmap

- Remote Terraform state in Azure Storage
- GitHub Actions / Azure OIDC authentication
- Automated Terraform validation and security scanning
- `ansible-lint` and `yamllint`
- Checkov Terraform scanning
- Azure Monitor / Log Analytics expansion
- Additional Grafana dashboards
- Evaluate Tailscale workload identity federation for bootstrap authentication
- Further documentation for disaster recovery and backup restoration
