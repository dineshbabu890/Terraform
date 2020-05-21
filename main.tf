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

resource "azurerm_container_registry" "primary" {
  name                = "${local.namespace}${local.environment}"
  resource_group_name = module.aks_eastus_alpha.resource_group.name
  location            = var.location 
  sku                 = "Standard"
  admin_enabled       = true
}



module "aks_eastus" {
  source   = "git::https://github.optum.com/optumcaredataplatform/terraform-aks//modules/aks_region"
  namespace     = local.namespace
  environment   = local.environment
  location      = "${var.location}"
  address_space = ["10.16.0.0/12"] #This is 10.16.*.* through 10.31.*.* to give us plenty of spaces for additional subnets
}

module "aks_eastus_alpha" {
  source   = "git::https://github.optum.com/optumcaredataplatform/terraform-aks//modules/aks_cluster"
  namespace                  = local.namespace
  environment                = local.environment
  location                   = "${var.location}"
  instance                   = "${var.cluster_name}"
  log_analytics_workspace = module.aks_eastus.log_analytics_workspace
  virtual_network            = module.aks_eastus.virtual_network
  pod_address_space          = "10.16.0.0/16" # The entire 10.16.*.* range, a subnet will be created for this in the module
  #The internal service addresses are not routable from azure, and we give them a totally separate range to make this clear
  service_address_space      = "172.16.0.0/16" 
  kubernetes_version         = "${var.aks_version}"
  enable_default_nsg         = true

  # See below for the process to create these applications
  rbac = local.rbac

 
    default_node_pool = {
    name               = "primary"
    node_count         = "${var.vm_count}"
    vm_size            = "${var.vm_size}"
    os_disk_size_gb    = 30
    availability_zones = null
    node_taints        = null
  }

  #container_registries = [
  #  azurerm_container_registry.primary
  #]
}



/*
resource "null_resource" "acr_upload_tiller" {
    depends_on = ["azurerm_container_registry.primary"]
    provisioner "local-exec" {
        command = "./docker_image_upload.sh ${azurerm_container_registry.primary.name} ${azurerm_container_registry.primary.login_server} docker.repo1.uhc.com ${var.artifactory_user} ${var.artifactory_pw} ${azurerm_container_registry.primary.name} ${azurerm_container_registry.primary.admin_password} kubernetes-helm/tiller:v2.14.1"
    }
}


resource "null_resource" "acr_attach" {
    depends_on = ["module.aks_eastus_alpha","null_resource.acr_upload_tiller"]
     triggers = {
        build_number = "${timestamp()}"
    }
    provisioner "local-exec" {
        command = "az aks update -n ${module.aks_eastus_alpha.cluster.name} -g ${module.aks_eastus_alpha.resource_group.name} --attach-acr ${azurerm_container_registry.primary.name}"
    }
}

resource "null_resource" "helm_init" {
    depends_on = ["module.aks_eastus_alpha","null_resource.acr_upload_tiller", "null_resource.acr_attach"]
     triggers = {
        build_number = "${timestamp()}"
    }
    provisioner "local-exec" {
        command = "./helm_install.sh ${module.aks_eastus_alpha.cluster.name} ${module.aks_eastus_alpha.resource_group.name} ${azurerm_container_registry.primary.login_server}/kubernetes-helm/tiller:v2.14.1"
    }
}
 */

/*
#subnet for ingress
#add to nsg  This will throw a warning, which Terraform says is required right now
resource "azurerm_subnet" "ingress_subnet" {
  name                      = "ingress-subnet"
  resource_group_name       = "${local.namespace}-${local.environment}-aks-${var.location}"
  virtual_network_name      = module.aks_eastus.virtual_network.name
  address_prefix            = "10.18.0.0/24"
  route_table_id            = module.aks_eastus_alpha.route_table.id
  network_security_group_id = module.aks_eastus_alpha.subnet_network_security_group.id
}

resource "azurerm_subnet_route_table_association" "ingress_subnet" {
  subnet_id      = azurerm_subnet.ingress_subnet.id
  route_table_id = module.aks_eastus_alpha.route_table.id
} */



/*
#subnet for apim
# no nsg
resource "azurerm_subnet" "api_management_subnet" {
  name                      = "api-management-subnet"
  resource_group_name       = "${local.namespace}-${local.environment}-aks-${var.location}"
  virtual_network_name      = module.aks_eastus.virtual_network.name
  address_prefix            = "10.19.0.0/29"
  route_table_id            = module.aks_eastus_alpha.route_table.id
}

resource "azurerm_subnet_route_table_association" "api_management_subnet" {
  subnet_id      = azurerm_subnet.api_management_subnet.id
  route_table_id = module.aks_eastus_alpha.route_table.id
}


resource "azurerm_network_security_rule" "allow_apim_subnet" {
  count                       = 1
  name                        = "allow-apim-https-in"
  description                 = "Allow inbound traffic from apim subnet"
  priority                    = 1400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "10.19.0.0/29"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  resource_group_name         = module.aks_eastus_alpha.resource_group.name
  network_security_group_name = module.aks_eastus_alpha.subnet_network_security_group.name
}


resource "azurerm_network_security_rule" "network_security_rule_https" {
  name                        = "UHG-HTTPS"
  priority                    = "2000"
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "TCP"
  source_port_range           = "*"
  destination_port_ranges     = ["443"]
  source_address_prefixes     = local.optum_ip_whitelist
  destination_address_prefix  = "*"
  resource_group_name         = module.aks_eastus_alpha.resource_group.name
  network_security_group_name = module.aks_eastus_alpha.subnet_network_security_group.name
}


resource "azurerm_network_security_rule" "allow_internet_https_inbound" {
  name                        = "allow-internet-https-in"
  description                 = "Allow inbound HTTPS from the internet"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = 443
  resource_group_name         = module.aks_eastus_alpha.resource_group.name
  network_security_group_name = module.aks_eastus_alpha.subnet_network_security_group.name
}

*/

resource "azurerm_dns_zone" "dns_zone" {
  name                = var.domain
  resource_group_name = module.aks_eastus_alpha.resource_group.name
}

resource "azurerm_public_ip" "kafka_broker" {
  name                = "kafka-broker-${count.index}"
  location            = var.location 
// needs to be in the aks system resource group unless we add annotations to all of the LoadBalancer definitions to override the resource group  
  resource_group_name = "${local.namespace}-${local.environment}-aks-${var.location}-akscluster-system"
  sku = "Standard"
  allocation_method   = "Static"

  tags = {
    service = "broker"
  }
   count = var.kafka_broker_count
}

resource "azurerm_dns_a_record" "kafka-broker" {
  name                = "kafka-${count.index}"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = module.aks_eastus_alpha.resource_group.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.kafka_broker[count.index].id
  count = var.kafka_broker_count
}


resource "azurerm_public_ip" "schema_registry" {
  name                = "schema-registry"
  location            = var.location 
// needs to be in the aks system resource group unless we add annotations to all of the LoadBalancer definitions to override the resource group  
  resource_group_name = "${local.namespace}-${local.environment}-aks-${var.location}-akscluster-system"
  sku = "Standard"
  allocation_method   = "Static"

  tags = {
    service = "schema-registry"
  }
}

resource "azurerm_dns_a_record" "schema-registry" {
  name                = "schema"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = module.aks_eastus_alpha.resource_group.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.schema_registry.id

}

resource "azurerm_public_ip" "grafana" {
  name                = "grafana"
  location            = var.location
// needs to be in the aks system resource group unless we add annotations to all of the LoadBalancer definitions to override the resource group  
  resource_group_name = "${local.namespace}-${local.environment}-aks-${var.location}-akscluster-system"
  sku = "Standard"
  allocation_method   = "Static"

  tags = {
    service = "grafana"
  }
}

resource "azurerm_dns_a_record" "grafana" {
  name                = "grafana"
  zone_name           = azurerm_dns_zone.dns_zone.name
  resource_group_name = module.aks_eastus_alpha.resource_group.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.grafana.id
}

