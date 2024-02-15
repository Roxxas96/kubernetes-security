resource "kubernetes_namespace_v1" "kube-prometheus-stack" {
  metadata {
    name = "kube-prometheus-stack"
  }
}

resource "helm_release" "kube-prometheus-stack" {
  name      = "kube-prometheus-stack"
  namespace = kubernetes_namespace_v1.kube-prometheus-stack.metadata[0].name

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"

  values = ["${file("./configs/kube-prometheus-stack.values.yaml")}"]
}
