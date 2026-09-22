# ============================================================
# Existing Azure Resources
# ============================================================

# Existing resource groups
data "azurerm_resource_group" "labs" {
  name = "Labs"
}

data "azurerm_resource_group" "util" {
  name = "rg-hmlb-util"
}


# ============================================================
# Existing Azure Arc Machines
# ============================================================

data "azurerm_arc_machine" "minecraft" {
  name                = "minecraft"
  resource_group_name = data.azurerm_resource_group.labs.name
}

data "azurerm_arc_machine" "media_vps" {
  name                = "media-vps"
  resource_group_name = data.azurerm_resource_group.labs.name
}


# ============================================================
# Log Analytics Workspace
# ============================================================

resource "azurerm_log_analytics_workspace" "security" {
  name                = "law-hmlb-sec"
  location            = data.azurerm_resource_group.util.location
  resource_group_name = data.azurerm_resource_group.util.name

  sku               = "PerGB2018"
  retention_in_days = 30

  tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "SecurityMonitoring"
  }
}


# ============================================================
# Grafana Log Analytics Access
# ============================================================

resource "azurerm_role_assignment" "grafana_log_reader" {
  scope                = azurerm_log_analytics_workspace.security.id
  role_definition_name = "Log Analytics Data Reader"
  principal_id         = azurerm_linux_virtual_machine.utility.identity[0].principal_id
}
resource "azurerm_role_assignment" "grafana_subscription_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.utility.identity[0].principal_id
}

# ============================================================
# Linux Security Log Collection
# ============================================================

resource "azurerm_monitor_data_collection_rule" "linux_security" {
  name                = "dcr-hmlb-linux-security"
  location            = data.azurerm_resource_group.util.location
  resource_group_name = data.azurerm_resource_group.util.name
  kind                = "Linux"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.security.id
      name                  = "security-law"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["security-law"]
  }

  data_sources {
    syslog {
      name = "linux-auth"

      facility_names = [
        "auth",
        "authpriv"
      ]

      log_levels = ["*"]

      streams = [
        "Microsoft-Syslog"
      ]
    }
  }

  tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "SecurityMonitoring"
  }
}


# ============================================================
# Data Collection Rule Associations
# ============================================================

resource "azurerm_monitor_data_collection_rule_association" "minecraft_security" {
  name                    = "dcra-security-minecraft"
  target_resource_id      = data.azurerm_arc_machine.minecraft.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux_security.id
}

resource "azurerm_monitor_data_collection_rule_association" "media_vps_security" {
  name                    = "dcra-security-media-vps"
  target_resource_id      = data.azurerm_arc_machine.media_vps.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.linux_security.id
}


# ============================================================
# Alert Notifications
# ============================================================

resource "azurerm_monitor_action_group" "security" {
  name                = "ag-hmlb-security"
  resource_group_name = data.azurerm_resource_group.util.name
  short_name          = "hmlbsec"

  email_receiver {
    name                    = "security-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "SecurityMonitoring"
  }
}


# ============================================================
# Security Detection: SSH Brute Force
# ============================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "ssh_bruteforce" {
  name                = "alert-hmlb-ssh-bruteforce"
  location            = data.azurerm_resource_group.util.location
  resource_group_name = data.azurerm_resource_group.util.name

  scopes = [
    azurerm_log_analytics_workspace.security.id
  ]

  description = "Detects five or more failed SSH authentication attempts against a hybrid Linux host within five minutes."

  severity = 2
  enabled  = true

  evaluation_frequency = "PT1M"
  window_duration      = "PT5M"

  criteria {
    query = <<-KQL
      Syslog
      | where ProcessName startswith "sshd"
      | where SyslogMessage has_any (
          "Failed password",
          "Failed publickey",
          "Invalid user",
          "authentication failure"
        )
      | summarize FailedAttempts = count() by Computer
    KQL

    metric_measure_column   = "FailedAttempts"
    time_aggregation_method = "Maximum"
    operator                = "GreaterThanOrEqual"
    threshold               = 5

    dimension {
      name     = "Computer"
      operator = "Include"
      values   = ["*"]
    }

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [
      azurerm_monitor_action_group.security.id
    ]
  }

  auto_mitigation_enabled = true

  tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "SecurityMonitoring"
  }
}