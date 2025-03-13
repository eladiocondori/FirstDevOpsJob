# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
  subscription_id = "ddf74a51-169e-4498-96a6-f8e08327aea1"
}

locals {
  resource_name = "polyglot-microservices-terraform"
  sqlserver_name = "serverpolyglotsql-terraformeac"
  sqldatabase_name = "DB_ACCOUNT"
  postgresserver_name = "serverpolyglotpostgres-terraformeac"
  cosmosdbserver_name = "serverpolyglotcosmos-terraformeac"
  mongodatabase_name = "DB_TRANSACTION"
  appconfiguration_name = "configpolygloteac-terraform-training"
}

# Create a resource group
resource "azurerm_resource_group" "resource_group_training" {
  name     = local.resource_name
  location = "West US 2"
}

# Create a server SQL
resource "azurerm_mssql_server" "sql_server_training" {
  name                         = local.sqlserver_name
  resource_group_name          = azurerm_resource_group.resource_group_training.name
  location                     = azurerm_resource_group.resource_group_training.location
  version                      = "12.0"
  administrator_login          = "polyglot"
  administrator_login_password = "P0l1gl0t#3000"

  tags = {
    environment = "production"
  }
}

# Create a firewaal rule for server SQL
resource "azurerm_mssql_firewall_rule" "firewall_sql_server_desktop_training" {
  name                = "serverpolyglotsql-terraform-firewallrule-desktop-all"
  server_id           = azurerm_mssql_server.sql_server_training.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

resource "azurerm_mssql_firewall_rule" "firewall_sql_azure_access_server_training" {
  name                = "serverpolyglotsql-terraform-firewallrule-access-to-azure"
  server_id           = azurerm_mssql_server.sql_server_training.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Create a Database SQL
resource "azurerm_mssql_database" "sql_server_training" {
  name           = local.sqldatabase_name
  server_id      = azurerm_mssql_server.sql_server_training.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  sku_name       = "S0"

  tags = {
    foo = "production"
  }
}


# Create a Database POSTGRESQL
resource "azurerm_postgresql_server" "postgres_server_training" {
  name                = local.postgresserver_name
  location            = azurerm_resource_group.resource_group_training.location
  resource_group_name = azurerm_resource_group.resource_group_training.name
  administrator_login          = "polyglot"
  administrator_login_password = "P0l1gl0t#3000"
  sku_name   = "B_Gen5_1"
  version    = "10"
  storage_mb = 5120
  public_network_access_enabled    = true
  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
  tags = {
    environment = "production"
  }
}

# Create a firewaal rule for server Postgres
resource "azurerm_postgresql_firewall_rule" "firewall_postress_server_desktop_training" {
  name                = "serverpolyglotpostgres-terraform-firewallrule-desktop-all"
  resource_group_name = azurerm_resource_group.resource_group_training.name
  server_name         = azurerm_postgresql_server.postgres_server_training.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

# Create a firewaal rule for server Postgres
resource "azurerm_postgresql_firewall_rule" "firewall_postress_azure_access_server_training" {
  name                = "serverpolyglotpostgres-terraform-firewallrule-access-to-azure"
  resource_group_name = azurerm_resource_group.resource_group_training.name
  server_name         = azurerm_postgresql_server.postgres_server_training.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}


# Create a Server COSMOSDB
resource "azurerm_cosmosdb_account" "cosmosdb_server_training" {
  name                = local.cosmosdbserver_name
  location            = azurerm_resource_group.resource_group_training.location
  resource_group_name = azurerm_resource_group.resource_group_training.name
  offer_type          = "Standard"
  kind                = "MongoDB"
  mongo_server_version = "4.0"
  
  tags = {
    environment = "production"
  }
  
  enable_free_tier = true
  enable_automatic_failover = true
  public_network_access_enabled = true

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }
  geo_location {
    location          = azurerm_resource_group.resource_group_training.location
    failover_priority = 0
  }
}

# Create a Database COSMOSDB
resource "azurerm_cosmosdb_mongo_database" "cosmosdb_server_db_training" {
  name = local.mongodatabase_name
  resource_group_name = azurerm_resource_group.resource_group_training.name
  account_name = azurerm_cosmosdb_account.cosmosdb_server_training.name
}

# Create a APP CONFIGURATION
resource "azurerm_app_configuration" "appconf_training" {
  name                = local.appconfiguration_name
  resource_group_name = azurerm_resource_group.resource_group_training.name
  location            = azurerm_resource_group.resource_group_training.location
  sku                 = "standard"
}

data "azuread_client_config" "current" {}

resource "azurerm_role_assignment" "appconf_dataowner" {
  scope                = azurerm_app_configuration.appconf_training.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azuread_client_config.current.object_id
  # principal_id         = data.azurerm_client_config.current.object_id
  # skip_service_principal_aad_check = true
}

output "client_id" {
  value = data.azuread_client_config.current.client_id
}

output "object_id" {
  value = data.azuread_client_config.current.object_id
}

# output "subscription_id" {
#   value = data.azuread_client_config.current.subscription_id
# }

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

resource "azurerm_app_configuration_key" "appconf_key_config_cn_security" {
  configuration_store_id = azurerm_app_configuration.appconf_training.id
  key                    = "CONFIG_CN_SECURITY"
  value                  = "Server=tcp:serverpolyglotsql-terraform.database.windows.net,1433;Initial Catalog=DB_SECURITY;Persist Security Info=False;User ID=polyglot;Password=@f0r0255#2020;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}

resource "azurerm_app_configuration_key" "appconf_key_config_cn_account" {
  configuration_store_id = azurerm_app_configuration.appconf_training.id
  key                    = "CONFIG_CN_ACCOUNT"
  value                  = "Server=tcp:serverpolyglotsql-terraform.database.windows.net,1433;Initial Catalog=DB_ACCOUNT;Persist Security Info=False;User ID=polyglot;Password=@f0r0255#2020;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}

resource "azurerm_app_configuration_key" "appconf_key_config_cn_transaction" {
  configuration_store_id = azurerm_app_configuration.appconf_training.id
  key                    = "CONFIG_CN_TRANSACTION"
  value                  = "Server=serverpolyglotpostgres-terraform.postgres.database.azure.com;Database=DB_TRANSACTION;Port=5432;User Id=polyglot@serverpolyglotpostgres-ica;Password=@f0r0255#2020;Ssl Mode=Require;Trust Server Certificate=true;"

  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}

resource "azurerm_app_configuration_key" "appconf_key_config_cn_movement" {
  configuration_store_id = azurerm_app_configuration.appconf_training.id
  key                    = "CONFIG_CN_MOVEMENT"
  value                  = azurerm_cosmosdb_account.cosmosdb_server_training.connection_strings[0]

  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}

resource "azurerm_app_configuration_key" "appconf_key_config_database_name_movement" {
  configuration_store_id = azurerm_app_configuration.appconf_training.id
  key                    = "CONFIG_DATABASE_MOVEMENT"
  value                  = "DB_TRANSACTION"

  depends_on = [
    azurerm_role_assignment.appconf_dataowner
  ]
}
