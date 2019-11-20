data "azurerm_subscription" "current" {}

provider "helm" {
  install_tiller  = true
  service_account = "tiller"

  kubernetes  {
    host                   = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)}"
  }
}

data "helm_repository" "chart_msi" {
    name = "aad-pod-identity"
    url  = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
}

#TODO TEST:
resource "helm_release" "aad-identity" {
  name       = "aad-release"
  repository = "aad-pod-identity"
  chart      = "aad-pod-identity/aad-pod-identity"

  set_string {
    name  = "azureIdentity.resourceID"
    value = "/subscriptions/${data.azurerm_subscription.current.id}/resourceGroups/${azurerm_resource_group.k8s.name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${azurerm_user_assigned_identity.k8s.name}"
  }

  set_string {
    name  = "azureIdentity.clientID"
    value = "${azurerm_user_assigned_identity.k8s.client_id}"
  }

  set_string {
    name  = "azureIdentityBinding.selector"
    value = "datalake-msi"
  }
}