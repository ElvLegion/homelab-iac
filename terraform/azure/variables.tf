variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}
variable "admin_ssh_public_key" {
  description = "SSH public key for the utility VM administrator"
  type        = string
}
variable "alert_email" {
  description = "Email address for Azure security alert notifications"
  type        = string
  sensitive   = true
}
