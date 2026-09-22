# Homelab Infrastructure as Code

[![Infrastructure CI](https://github.com/ElvLegion/homelab-iac/actions/workflows/ci.yml/badge.svg)](https://github.com/ElvLegion/homelab-iac/actions/workflows/ci.yml)

This repository demonstrates a security-focused hybrid homelab built and managed with Infrastructure as Code.

Terraform provisions the Azure management layer, Ansible configures the Linux utility host and monitoring stack, and Azure Arc extends Azure management and security telemetry to externally hosted systems. Authentication logs are centralized in Log Analytics, KQL detections generate Azure Monitor alerts, and Grafana provides a private security dashboard.

The design emphasizes reproducibility, least-privilege access, private administration through Tailscale, managed identities instead of stored cloud credentials, and automated infrastructure validation through GitHub Actions.

## Architecture

```text
                           Azure
                             |
                     vm-hmlb-util
                     Ubuntu 26.04
                             |
        +--------------------+--------------------+
        |                    |                    |
      Caddy                Gatus                Grafana
   public HTTPS        availability          security views
                           checks                  |
                                                  |
                                           Managed Identity
                                                  |
                                                  v
                                           Log Analytics
                                                  ^
                                                  |
                                         Data Collection Rule
                                                  ^
                                                  |
                                   Azure Monitor Agent / Arc
                                      /                 \
                                     /                   \
                              minecraft               media-vps
                               On-Prem                 Interserver


Security detection path:

Linux authentication logs
        |
        v
Azure Monitor Agent
        |
        v
Data Collection Rule
        |
        v
Log Analytics
        |
        +----> Grafana security dashboard
        |
        +----> KQL scheduled-query alert
                    |
                    v
              Action Group
                    |
                    v
              Email notification


Administrative access:

Workstation
    |
 Tailscale
    |
    v
vm-hmlb-util
    |
    +---- SSH / Ansible
    |
    +---- Grafana via Tailscale Serve
```

`vm-hmlb-util` is the Azure utility VM managed by this repository.

The `minecraft` and `media-vps` hosts are externally managed Linux systems. They are monitored from the utility VM and connected to Azure Arc, but this repository does not currently provision those hosts or perform their initial Arc enrollment.

## What This Project Uses

- **Terraform** - provisions Azure infrastructure, monitoring resources, RBAC, and alerting
- **cloud-init** - performs first-boot Tailscale enrollment
- **Azure Managed Identity** - provides Azure access without embedded cloud credentials
- **Azure Key Vault** - stores the Tailscale bootstrap credential
- **Azure Arc** - connects externally hosted Linux systems to Azure
- **Azure Monitor Agent** - collects Linux security telemetry
- **Azure Monitor Data Collection Rules** - route authentication logs into Log Analytics
- **Log Analytics** - centralizes security events and provides KQL querying
- **Azure Monitor Alerts** - detects suspicious authentication activity
- **Ansible** - configures and maintains the Linux utility VM
- **Docker Compose** - deploys the monitoring stack
- **Tailscale** - provides the private management network
- **Caddy** - handles public HTTPS for the status endpoint
- **Gatus** - performs service and availability monitoring
- **Grafana** - provides private security and monitoring dashboards
- **GitHub Actions** - validates Terraform, Ansible, YAML, and Checkov security findings

## Repository Layout

```text
homelab-iac/
├── .github/
│   └── workflows/
│
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
├── terraform/
│   └── azure/
│       ├── bootstrap-secrets.tf
│       ├── cloud-init.yaml.tftpl
│       ├── locals.tf
│       ├── monitoring.tf
│       ├── network-interface.tf
│       ├── network.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── resource-group.tf
│       ├── variables.tf
│       ├── versions.tf
│       └── vm.tf
│
├── README.md
└── SECURITY.md
```

## Azure Infrastructure

Terraform currently provisions and manages:

- Azure resource group
- Virtual network and subnet
- Network security group
- Static public IP
- Network interface
- Ubuntu 26.04 utility VM
- System-assigned managed identity
- User-assigned bootstrap managed identity
- Azure Key Vault
- Key Vault RBAC assignment
- Log Analytics workspace
- Azure Monitor Data Collection Rule
- Data Collection Rule associations for Azure Arc systems
- Grafana Log Analytics RBAC access
- Azure Monitor Action Group
- KQL-based SSH brute-force detection
- Scheduled-query alerting

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

This avoids the bootstrap problem where Ansible would require SSH access before the private management network existed.

The Tailscale credential is not stored directly in the Terraform configuration or passed on the command line. The VM retrieves it from Key Vault using its managed identity.

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

The bootstrap playbook is designed to be idempotent. A second run should normally complete with:

```text
changed=0
failed=0
```

## Security Model

Administrative access is intentionally separated from public application traffic.

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

Grafana and Gatus are not directly exposed through their Docker ports.

Their bindings are:

```text
Grafana   127.0.0.1:3000
Gatus     127.0.0.1:8080
```

Caddy is the only monitoring container with public HTTP/HTTPS bindings.

Grafana administration is available through the private Tailscale network.

SSH private keys, Terraform variable files, Terraform state, authentication secrets, and local environment files are excluded from Git.

Membership in the Docker group should be treated as root-equivalent access to the host.

Additional security decisions and documented Checkov exceptions are described in [`SECURITY.md`](SECURITY.md).

## Monitoring Stack

### Gatus

Gatus performs availability checks for services including:

- Jellyfin
- Minecraft infrastructure
- Media VPS infrastructure

The public status page is available at:

```text
https://status.elvishlegion.com
```

Gatus itself remains bound to the loopback interface and is exposed publicly through Caddy.

### Grafana

Grafana is deployed privately and remains bound to:

```text
127.0.0.1:3000
```

It is not directly exposed to the public Internet.

Grafana is currently made available to authorized tailnet devices through Tailscale Serve while the underlying container remains loopback-only.

The Azure Monitor data source authenticates using the Azure utility VM's system-assigned managed identity rather than a stored client secret.

The managed identity has:

- `Log Analytics Data Reader` access to the security Log Analytics workspace
- `Reader` access at the Azure subscription level

The security dashboard currently visualizes:

- failed SSH authentication attempts
- SSH failure trends
- failures by host
- top failed SSH source addresses
- successful SSH logins
- sudo activity
- recent authentication and security events

## Security Monitoring and Detection

Authentication telemetry from the Azure Arc-enabled `minecraft` and `media-vps` systems is collected by Azure Monitor Agent.

A Terraform-managed Data Collection Rule collects the Linux `auth` and `authpriv` Syslog facilities and routes those events into a dedicated Log Analytics workspace.

The initial security detection identifies repeated SSH authentication failures.

The scheduled query evaluates once per minute over a five-minute window and triggers when a host records five or more failed authentication attempts.

Events considered include:

- failed password authentication
- failed public-key authentication
- invalid usernames
- PAM authentication failures

The detection logic is implemented in KQL:

```kusto
Syslog
| where ProcessName startswith "sshd"
| where SyslogMessage has_any (
    "Failed password",
    "Failed publickey",
    "Invalid user",
    "authentication failure"
)
| summarize FailedAttempts = count() by Computer
```

When the threshold is reached, Azure Monitor raises a severity 2 alert and an Action Group sends an email notification.

The detection pipeline has been tested end-to-end by intentionally generating failed SSH authentication attempts and verifying:

```text
Linux authentication event
        |
        v
Azure Monitor Agent
        |
        v
Data Collection Rule
        |
        v
Log Analytics ingestion
        |
        v
KQL detection
        |
        v
Azure Monitor alert
        |
        v
Action Group notification
```

Grafana queries the same Log Analytics data to provide a visual security-operations view of the environment.

## Container Hardening

Monitoring container images are pinned by immutable image digest.

Docker JSON logs are rotated with:

```text
max-size: 10m
max-file: 3
```

The Ansible monitoring playbook verifies Gatus and Grafana health after deployment.

Changes to the Caddy configuration are validated before Caddy is reloaded.

## Continuous Integration

GitHub Actions validates infrastructure changes on pull requests and pushes to `main`.

The current CI workflow includes:

- Terraform formatting checks
- Terraform validation
- Checkov Terraform security scanning
- `ansible-lint`
- `yamllint`

Security-scanner findings are reviewed against the intended architecture instead of being ignored solely to achieve a perfect scanner score.

Documented exceptions and their rationale are maintained in [`SECURITY.md`](SECURITY.md).

## Terraform Usage

Terraform is currently run locally.

From PowerShell:

```powershell
$env:TF_VAR_subscription_id = (az account show --query id -o tsv).Trim()
$env:TF_VAR_admin_ssh_public_key = (Get-Content "$env:USERPROFILE\.ssh\hmlb_azure.pub" -Raw).Trim()
$env:TF_VAR_alert_email = "your-alert-address@example.com"

terraform init
terraform validate
terraform plan
terraform apply
```

The alert email is supplied through a sensitive Terraform variable and is not stored in the repository.

Terraform state may contain sensitive infrastructure values and is excluded from Git.

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

The process has been tested by destroying and recreating `vm-hmlb-util`, allowing the replacement VM to join Tailscale automatically before Ansible configuration was applied.

Application data and persistent backups remain separate from infrastructure code.

## Azure Arc

The following external hosts are connected to Azure Arc:

- `minecraft`
- `media-vps`

Azure Monitor Agent on those systems provides authentication telemetry to the centralized Log Analytics workspace.

Initial Arc enrollment is currently managed outside this repository.

The repository should therefore not be interpreted as a complete rebuild mechanism for those external hosts.

## Current Limitations

- Terraform state is stored locally
- Tailscale bootstrap depends on a valid unused authentication key in Key Vault
- Azure Arc enrollment is not currently codified
- Grafana Azure Monitor provisioning is not yet fully represented in the repository
- Tailscale Serve configuration is not yet managed by Ansible
- Monitoring application data is stored in Docker volumes rather than managed by Terraform
- The externally managed Minecraft and media hosts remain outside the Terraform lifecycle

## Completed Improvements

- Reproducible Azure utility infrastructure with Terraform
- First-boot Tailscale enrollment through cloud-init
- Managed-identity access to Azure Key Vault
- Tailscale-only administrative SSH access
- Ansible host configuration
- Docker Compose monitoring deployment
- GitHub Actions infrastructure validation
- Terraform formatting and validation
- Checkov Terraform security scanning
- `ansible-lint`
- `yamllint`
- Azure Arc hybrid management
- Azure Monitor Agent security-log collection
- Centralized Log Analytics workspace
- Terraform-managed Data Collection Rules
- KQL SSH brute-force detection
- Azure Monitor scheduled-query alerting
- Action Group email notification
- Grafana security dashboard backed by Log Analytics
- Managed-identity authentication between Grafana and Azure

## Roadmap

- Remote Terraform state in Azure Storage
- GitHub Actions authentication to Azure using OIDC
- Codify Grafana Azure Monitor datasource provisioning
- Codify Tailscale Serve configuration
- Add additional security detections beyond SSH authentication
- Automate Azure Arc enrollment
- Expand Grafana security and infrastructure dashboards
- Evaluate Tailscale workload identity federation for bootstrap authentication
- Add disaster-recovery and backup-restoration documentation