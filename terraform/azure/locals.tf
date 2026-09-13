locals {
  location = "centralus"

  common_tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "Utility"
  }
}
