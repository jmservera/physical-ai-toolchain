/**
 * # Conversion Pipeline Module
 *
 * The conversion pipeline reuses the platform-owned ADLS Gen2 data-lake
 * account (stdl...) for raw -> converted storage. This module owns only the
 * Event Grid system topic + subscription that route BlobCreated events to the
 * conversion subscriber, an in-account dead-letter container, and the Fabric
 * capacity + workspace.
 */

locals {
  resource_name_suffix                 = "${var.resource_prefix}-${var.environment}-${var.instance}"
  location                             = coalesce(var.location, var.resource_group.location)
  datasets_immutability_period_in_days = max(var.raw_immutability_period_in_days, var.converted_immutability_period_in_days)
}

// ============================================================
// Datasets Container Immutability
// ============================================================
// Azure Blob immutability is container-scoped. The platform module stores both
// raw/ and converted/ prefixes inside the shared datasets container, so one
// policy covers both prefixes and uses the longer retention window.

resource "azurerm_storage_container_immutability_policy" "datasets" {
  count = var.should_enable_immutability_policy ? 1 : 0

  storage_container_resource_manager_id = var.datasets_container.id
  immutability_period_in_days           = local.datasets_immutability_period_in_days
}

// ============================================================
// Event Grid Dead-Letter Container
// ============================================================

resource "azurerm_storage_container" "event_grid_dlq" {
  count = var.should_enable_event_grid_dead_letter ? 1 : 0

  name                  = "event-grid-dlq"
  storage_account_id    = var.data_lake_storage_account.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container_immutability_policy" "event_grid_dlq" {
  count = var.should_enable_immutability_policy && var.should_enable_event_grid_dead_letter ? 1 : 0

  storage_container_resource_manager_id = azurerm_storage_container.event_grid_dlq[0].id
  immutability_period_in_days           = var.event_grid_dlq_immutability_period_in_days
}
