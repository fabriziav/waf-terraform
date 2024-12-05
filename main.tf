terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.12.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = var.az_subscription
  client_id       = var.az_clientid
  client_secret   = var.az_clientsecret
  tenant_id       = var.az_tenantid
}

variable "az_clientid" {}
variable "az_clientsecret" {}
variable "az_tenantid" {}
variable "az_subscription" {}

variable "admin_password" {
  type = string
}

variable "vnet_cidr" {
  type        = string
  description = "The CIDR block for the VNET"
  // default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
  // default     = "10.10.10.0/24"
}


variable "rg" {
  type = string
}

variable "rg_location" {
  type = string
}

resource "azurerm_resource_group" "waf" {
  name     = var.rg
  location = var.rg_location
}

# Create a Virtual Network
resource "azurerm_virtual_network" "waf" {
  name                = "waf-tf-network"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.waf.location
  resource_group_name = azurerm_resource_group.waf.name
}

# Create a Subnet
resource "azurerm_subnet" "waf" {
  name                 = "waf-tf-subnet"
  resource_group_name  = azurerm_resource_group.waf.name
  virtual_network_name = azurerm_virtual_network.waf.name
  address_prefixes     = [var.subnet_cidr]
}

variable "vault" {
  type = string
}

variable "vmsize" {
  type = string
}

resource "azurerm_linux_virtual_machine_scale_set" "waf" {
  name                = "waf-tf-vmss"
  resource_group_name = azurerm_resource_group.waf.name
  location            = azurerm_resource_group.waf.location
  sku                 = var.vmsize // "Standard_DS2_v2"
  instances           = 2
  overprovision = false


identity {
    type = "SystemAssigned"
  }

  tags = {
    vault = var.vault 
  }

  admin_username      = "cpadmin"

  admin_password                  = var.admin_password 
  disable_password_authentication = false

  source_image_reference {
    publisher = "checkpoint"
    offer     = "infinity-gw"
    sku       = "infinity-img"
    version   = "latest"
  }

  plan {
    publisher = "checkpoint"
    product   = "infinity-gw"
    name      = "infinity-img"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface {
    name    = "waf-tf-vmss-nic"
    primary = true

    ip_configuration {
      name      = "waf-tf-vmss-ip-config"
      subnet_id = azurerm_subnet.waf.id
      primary   = true

      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.waf.id]
      public_ip_address  {
        //sku = "Standard"
        name = "waf-tf-vmss-public-ip"
      }
    }

    network_security_group_id = azurerm_network_security_group.waf.id

   
  }

boot_diagnostics {}

  custom_data = base64encode(
    templatefile("${path.module}/custom-data.sh", {
      token = var.token,
      vnet  = var.vnet_cidr
  }))
}

variable "token" {
  type      = string
  sensitive = true
}

# random 6 digit number
resource "random_id" "waf" {
  byte_length = 4
}

# Create a public IP address
resource "azurerm_public_ip" "waf" {
  name                = "waf-tf-public-ip"
  location            = azurerm_resource_group.waf.location
  resource_group_name = azurerm_resource_group.waf.name
  allocation_method   = "Static"
  domain_name_label    = "wafpoc-${random_id.waf.hex}"
}

# output DNS name
output "waf-dns" {
  value = azurerm_public_ip.waf.fqdn
}
# and IP
output "waf-ip" {
  value = azurerm_public_ip.waf.ip_address
}

# Create a Network Security Group and rule
resource "azurerm_network_security_group" "waf" {
  name                = "waf-tf-nsg"
  location            = azurerm_resource_group.waf.location
  resource_group_name = azurerm_resource_group.waf.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  # HTTPS
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    # Probe
  security_rule {
    name                       = "probe"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8117"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# vmss system identity
output "vmss_identity" {
  value = azurerm_linux_virtual_machine_scale_set.waf.identity[0].principal_id
}
