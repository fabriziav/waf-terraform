terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.12.0"
    }
  }
}

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

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = "f4ad5e85-ec75-4321-8854-ed7eb611f61d"
}

variable "rg" {
  type = string
}

resource "azurerm_resource_group" "waf" {
  name     = var.rg
  location = "West Europe"
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

# Ubuntu Linux Virtual Machine with public IP
# resource "azurerm_linux_virtual_machine" "waf" {
#   name                = "waf-tf-vm"
#   resource_group_name = azurerm_resource_group.waf.name
#   location            = azurerm_resource_group.waf.location
#   size                = "Standard_DS2_v2"

#   admin_username = "cpadmin"

#   network_interface_ids = [azurerm_network_interface.waf.id]

#   # admin_ssh_key {
#   #   username   = "admin"
#   #   public_key = file("~/.ssh/id_rsa.pub")
#   # }

#   # allow using password
#   admin_password                  = "Bad Joke 1234"
#   disable_password_authentication = false

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "checkpoint"
#     offer     = "infinity-gw"
#     sku       = "infinity-img"
#     version   = "latest"
#   }

#   plan {
#     publisher = "checkpoint"
#     product   = "infinity-gw"
#     name      = "infinity-img"
#   }



#   custom_data = base64encode(
#     templatefile("${path.module}/custom-data.sh", {
#       token = var.token,
#       vnet  = var.vnet_cidr
#   }))
# }

variable "vault" {
  type = string
}

resource "azurerm_linux_virtual_machine_scale_set" "waf" {
  name                = "waf-tf-vmss"
  resource_group_name = azurerm_resource_group.waf.name
  location            = azurerm_resource_group.waf.location
  sku                 = "Standard_DS2_v2"
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

# Create a public IP address
resource "azurerm_public_ip" "waf" {
  name                = "waf-tf-public-ip"
  location            = azurerm_resource_group.waf.location
  resource_group_name = azurerm_resource_group.waf.name
  allocation_method   = "Static"
}

# # Create a Network Interface
# resource "azurerm_network_interface" "waf" {
#   name                = "waf-tf-nic"
#   location            = azurerm_resource_group.waf.location
#   resource_group_name = azurerm_resource_group.waf.name

#   ip_configuration {
#     name                          = "waf-tf-ip-config"
#     subnet_id                     = azurerm_subnet.waf.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.waf.id
#   }
# }

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

# # Associate the Network Security Group with the Network Interface
# resource "azurerm_network_interface_security_group_association" "waf" {
#   network_interface_id      = azurerm_network_interface.waf.id
#   network_security_group_id = azurerm_network_security_group.waf.id
# }