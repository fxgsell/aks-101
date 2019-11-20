variable "cluster_name" {}
variable "ssh_public_key" {}
variable "agent_count" {}
variable "location" {}
variable "kub_version" {}

provider "azuread" {}
provider "azurerm" {}

resource "random_pet" "cluster" {
  keepers = {
    # Generate a new pet name each time we switch to a new cluster name
    cluster_name = "${var.cluster_name}"
  }
  separator = ""
}

resource "azurerm_resource_group" "k8s" {
name     = "${var.cluster_name}-${random_pet.cluster.id}"
  location = "${var.location}"
}

resource "azurerm_log_analytics_workspace" "k8s" {
  name                = "${random_pet.cluster.id}-log"
  location            = "${azurerm_resource_group.k8s.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_virtual_network" "k8s_vnet" {
  name                = "${random_pet.cluster.id}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = "${azurerm_resource_group.k8s.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
}

resource "azurerm_subnet" "k8s_subnet" {
  name                 = "${random_pet.cluster.id}-subnet"
  resource_group_name  = "${azurerm_resource_group.k8s.name}"
  virtual_network_name = "${azurerm_virtual_network.k8s_vnet.name}"
  address_prefix       = "10.1.1.0/24"
}

resource "azurerm_user_assigned_identity" "k8s" {
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  location            = "${azurerm_resource_group.k8s.location}"

  name = "${random_pet.cluster.id}"
}
