
# AZ LB for VMSS of WAF instances

resource "azurerm_lb" "waf" {
  name                = "waf-tf-lb"
  resource_group_name = azurerm_resource_group.waf.name
  location            = azurerm_resource_group.waf.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.waf.id
  }
}

resource "azurerm_lb_backend_address_pool" "waf" {
  name                = "waf-tf-lb-backend-pool"
  // resource_group_name = azurerm_resource_group.waf.name
  loadbalancer_id     = azurerm_lb.waf.id
}

resource "azurerm_lb_probe" "waf" {
  name                = "waf-tf-lb-probe"
  // resource_group_name = azurerm_resource_group.waf.name
  loadbalancer_id     = azurerm_lb.waf.id
  protocol            = "Tcp"
  port                = 8117 //80 //8117
}

resource "azurerm_lb_rule" "waf" {
  name                     = "waf-tf-lb-rule"
  // resource_group_name      = azurerm_resource_group.waf.name
  loadbalancer_id          = azurerm_lb.waf.id
  // backend_address_pool_id  = azurerm_lb_backend_address_pool.waf.id

  backend_address_pool_ids  = [azurerm_lb_backend_address_pool.waf.id]
  probe_id                 = azurerm_lb_probe.waf.id
  frontend_ip_configuration_name = azurerm_lb.waf.frontend_ip_configuration[0].name
  frontend_port            = 80
  backend_port             = 80
  protocol                 = "Tcp"
}

resource "azurerm_lb_rule" "waf443" {
  name                     = "waf-tf-lb-rule443"
  // resource_group_name      = azurerm_resource_group.waf.name
  loadbalancer_id          = azurerm_lb.waf.id
  // backend_address_pool_id  = azurerm_lb_backend_address_pool.waf.id

  backend_address_pool_ids  = [azurerm_lb_backend_address_pool.waf.id]
  probe_id                 = azurerm_lb_probe.waf.id
  frontend_ip_configuration_name = azurerm_lb.waf.frontend_ip_configuration[0].name
  frontend_port            = 443
  backend_port             = 443
  protocol                 = "Tcp"
}


# resource "azurerm_network_interface_backend_address_pool_association" "waf" {
#   count                    = var.waf_instance_count
#   network_interface_id     = element(azurerm_network_interface.waf[*].id, count.index)
#   ip_configuration_name     = "ipconfig"
#   backend_address_pool_id  = azurerm_lb_backend_address_pool.waf.id
# }