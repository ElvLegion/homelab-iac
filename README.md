# Homelab Infrastructure as Code

Infrastructure-as-Code project for managing a hybrid homelab using Azure, Terraform, Ansible, Docker, Tailscale, and Azure Arc.

The goal is to make the management and monitoring infrastructure reproducible while keeping the actual workloads where they make the most sense.

## Architecture

```text
                    Azure
                      |
             vm-hmlb-util
             Ubuntu 26.04
                      |
         +------------+------------+
         |                         |
      Grafana                    Gatus
   private/admin              status checks
         |                         |
         +-----------+-------------+
                     |
                  Tailscale
                     |
          +----------+----------+
          |                     |
      minecraft              media-vps
      On-Prem               Interserver
          |                     |
          +------ Azure Arc ----+
What This Project Uses
Terraform - provisions Azure infrastructure
Ansible - configures and maintains Linux hosts
Docker Compose - deploys application workloads
Tailscale - private management network
Azure Arc - connects non-Azure Linux servers to Azure
Grafana - metrics and visualization
Gatus - lightweight service and availability monitoring
GitHub - off-site source control
Repository Layout
homelab-iac/
├── ansible/
│   ├── bootstrap.yml
│   ├── maintenance.yml
│   ├── monitoring.yml
│   ├── tailscale.yml
│   ├── inventory.yml
│   └── files/
│       └── monitoring/
│           ├── compose.yml
│           └── gatus/
│               └── config.yaml
│
└── terraform/
    └── azure/
        ├── versions.tf
        ├── providers.tf
        ├── variables.tf
        ├── locals.tf
        ├── resource-group.tf
        ├── network.tf
        ├── network-interface.tf
        ├── vm.tf
        └── outputs.tf
Current Infrastructure

Terraform currently provisions:

Azure resource group
Virtual network and subnet
Network security group
Static public IP
Network interface
Ubuntu 26.04 utility VM
System-assigned managed identity

The VM is configured by Ansible with:

Docker Engine
Docker Compose
Tailscale
UFW
SSH key authentication
Automatic package maintenance playbook
Security Model

SSH is not exposed to the public Internet.

Administrative access follows:
Workstation
    |
 Tailscale
    |
 SSH / Ansible
    |
vm-hmlb-util
The Azure NSG exposes only HTTP/HTTPS for future web services.

UFW permits SSH only through tailscale0.

Secrets, SSH private keys, Terraform state, .tfvars, and Tailscale authentication keys are excluded from Git.

Monitoring

Gatus currently monitors:

Jellyfin HTTPS availability
Minecraft server reachability over Tailscale
Media VPS reachability over Tailscale

Grafana is deployed but remains private while the Azure Monitor / Log Analytics integration is developed.

Terraform

Set the Azure subscription ID before running Terraform:
$env:TF_VAR_subscription_id = az account show --query id -o tsv
terraform init
terraform plan
terraform apply

Ansible

Ansible is run from Ubuntu under WSL.

Test connectivity:

ansible all -i inventory.yml -m ping
ansible-playbook -i inventory.yml bootstrap.yml
Deploy the monitoring stack:
ansible-playbook -i inventory.yml monitoring.yml
Apply OS updates:
ansible-playbook -i inventory.yml maintenance.yml
Rebuild Goal

The long-term objective is for the infrastructure to be recoverable using:

terraform apply
        |
        v
Azure infrastructure created
        |
        v
ansible-playbook
        |
        v
Host configured
        |
        v
Docker Compose
        |
        v
Applications restored
Application data and persistent backups are handled separately from the infrastructure code.

Roadmap
Azure Log Analytics workspace
Azure Monitor Agent for Arc-enabled servers
Data Collection Rules
CPU, memory, disk, and heartbeat monitoring
Grafana integration with Azure monitoring data
Caddy reverse proxy
status.elvishlegion.com
Remote Terraform state in Azure Storage
GitHub-based deployment automation
Version-pinned container images
