locals {
  postgres-svc = "${helm_release.database.metadata[0].name}-postgresql"
}

resource "kubernetes_namespace_v1" "echo" {
  metadata {
    name = "echo"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

variable "backend_url" {
  default = "http://localhost:3000"
}

resource "helm_release" "front" {
  name      = "front"
  namespace = kubernetes_namespace_v1.echo.metadata[0].name

  chart = "../front/chart/front"

  values = [templatefile("../front/chart/front/values.yaml", {
    backend-url = var.backend_url
  })]
}

resource "helm_release" "back" {
  name      = "back"
  namespace = kubernetes_namespace_v1.echo.metadata[0].name

  chart = "../back/chart/back"

  values = [templatefile("../back/chart/back/values.yaml", {
    postgres-host     = "${local.postgres-svc}.${kubernetes_namespace_v1.postgres.metadata[0].name}"
    postgres-username = var.postgres_username
    postgres-password = var.postgres_password
    postgres-database = var.postgres_database
  })]
}

resource "kubernetes_namespace_v1" "postgres" {
  metadata {
    name = "postgres"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

variable "postgres_username" {
  default = "postgres"
}
variable "postgres_password" {
  default = "postgres"
}
variable "postgres_database" {
  default = "postgres"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend = vault_mount.database.path
  name    = "postgres"

  postgresql {
    connection_url = "postgresql://${var.postgres_username}:${var.postgres_password}@${local.postgres-svc}.${kubernetes_namespace_v1.postgres.metadata[0].name}:5432/${var.postgres_database}"
  }
}

resource "helm_release" "database" {
  name      = "postgres"
  namespace = kubernetes_namespace_v1.postgres.metadata[0].name

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"

  values = [templatefile("./configs/postgresql.values.yaml", {
    username = var.postgres_username
    password = var.postgres_password
    database = var.postgres_database
  })]
}
