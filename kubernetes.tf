provider "kubernetes"  {
    host                   = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  # api_group has to be empty because of a bug:
  # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/204
  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
  }
}
resource "azuread_application" "k8s" {
  name = "k8s-${random_pet.cluster.id}"
}

resource  "azuread_service_principal" "k8s" {
  application_id = "${azuread_application.k8s.application_id}"
}

resource "random_string" "password" {
  length  = 32
  special = true
}

# Create Service Principal password
resource "azuread_service_principal_password" "k8s" {
  end_date             = "2299-12-30T23:00:00Z"                        # Forever
  service_principal_id = "${azuread_service_principal.k8s.id}"
  value                = "${random_string.password.result}"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${random_pet.cluster.id}"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  dns_prefix          = "${random_pet.cluster.id}"
  kubernetes_version  = "${var.kub_version}"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = "${file("${var.ssh_public_key}")}"
    }
  }

  network_profile {
    network_plugin = "azure"
  }

  agent_pool_profile {
    name            = "default"
    count           = "${var.agent_count}"
    vm_size         = "Standard_B2s"
    os_type         = "Linux"
    os_disk_size_gb = 30
    vnet_subnet_id  = "${azurerm_subnet.k8s_subnet.id}"
  }

  service_principal {
    client_id     = "${azuread_service_principal.k8s.application_id}"
    client_secret = "${azuread_service_principal_password.k8s.value}"
  }

  role_based_access_control {
    enabled = true
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8s.id}"
    }
  }
}