locals {
  namespace = "${var.namespace}"
  environment = "${var.env_name}"
  rbac = {
    client_app_id     = "${var.aks_client_app_id}"
    server_app_id     = "${var.aks_server_app_id}"
    server_app_secret = "${var.aks_server_secret}"
    tenant_id         = "db05faca-c82a-4b9d-b9c5-0f64b6755421"
  }
  optum_ip_whitelist = ["198.203.177.177", "198.203.175.175", "198.203.181.181", "168.183.84.12", "149.111.26.128", "149.111.28.128", "149.111.30.128", "220.227.15.70", "203.39.148.18", "161.249.192.14", "161.249.72.14", "161.249.80.14", "161.249.96.14", "161.249.144.14", "161.249.176.14", "161.249.16.0/23", "12.163.96.0/24"]
}


resource "azurerm_instance" "fhirserver" {
  name     = "${local.namespace}${local.environment}"
  location            = var.location 
  sku                 = "Standard"
  admin_enabled       = true
}

resource "azurerm_storage_account" "example" {
  name                     = "${var.prefix}stor"
  resource_group_name      = "${azurerm_resource_group.example.name}"
  location                 = "${azurerm_resource_group.example.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "example" {
  name                 = "aci-test-share"
  storage_account_name = "${azurerm_storage_account.example.name}"
  quota                = 50
}

resource "azurerm_container_group" "example" {
  name                = "${var.prefix}-continst"
  location            = "${azurerm_resource_group.example.location}"
  resource_group_name = "${azurerm_resource_group.example.name}"
  ip_address_type     = "public"
  dns_name_label      = "${var.prefix}-continst"
  os_type             = "linux"

  container {
    name     = "webserver"
    image    = "seanmckenna/aci-hellofiles"
    cpu      = "1"
    memory   = "1.5"
    port     = "80"
    protocol = "tcp"

    volume {
      name       = "logs"
      mount_path = "/aci/logs"
      read_only  = false
      share_name = "${azurerm_storage_share.example.name}"

      storage_account_name = "${azurerm_storage_account.example.name}"
      storage_account_key  = "${azurerm_storage_account.example.primary_access_key}"
    }
  }

  tags = {
    environment = "testing"
  }
}

