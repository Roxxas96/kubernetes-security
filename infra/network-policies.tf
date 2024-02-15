locals {
  backend_label  = "backend"
  database_label = "database"
}

resource "kubernetes_network_policy_v1" "backend-database" {
  metadata {
    name      = "backend-database"
    namespace = kubernetes_namespace_v1.echo.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        role = local.backend_label
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace_v1.postgres.metadata[0].name
          }
        }
        pod_selector {
          match_expressions {
            key      = "role"
            operator = "In"
            values   = [local.database_label]
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace_v1.postgres.metadata[0].name
          }
        }
        pod_selector {
          match_expressions {
            key      = "role"
            operator = "In"
            values   = [local.database_label]
          }
        }
      }
    }
  }
}
