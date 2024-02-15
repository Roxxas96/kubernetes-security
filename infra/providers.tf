terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.24.0"
    }
  }
}

provider "kubernetes" {
  config_context = "minikube"
  config_path    = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_context = "minikube"
    config_path    = "~/.kube/config"
  }
}

provider "kubectl" {
  config_context = "minikube"
  config_path    = "~/.kube/config"
}

variable "vault_token" {
  type        = string
  description = "Vault token to authenticate with the Vault server"
  sensitive   = true
}

provider "vault" {
  token   = var.vault_token
  address = "http://localhost:8200"
}
