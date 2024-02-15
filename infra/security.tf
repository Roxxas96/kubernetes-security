resource "kubernetes_namespace_v1" "kyverno" {
  metadata {
    name = "kyverno"
  }
}

resource "helm_release" "kyverno" {
  name      = "kyverno"
  namespace = kubernetes_namespace_v1.kyverno.metadata[0].name

  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"

  values = ["${file("./configs/kyverno.values.yaml")}"]
}

resource "helm_release" "kyverno-policies" {
  name      = "kyverno-policies"
  namespace = kubernetes_namespace_v1.kyverno.metadata[0].name

  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno-policies"

  values = ["${file("./configs/kyverno-policies.values.yaml")}"]

  depends_on = [helm_release.kyverno]
}

resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = "vault"
  }
}

resource "helm_release" "vault" {
  name      = "vault"
  namespace = kubernetes_namespace_v1.vault.metadata[0].name

  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"

  values = ["${file("./configs/vault.values.yaml")}"]
}

resource "vault_policy" "prometheus-metrics" {
  name   = "prometheus-metrics"
  policy = <<EOF
    path "sys/metrics" {
      capabilities = ["read"]
    }
    EOF
}

resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secret engine mount"
}
