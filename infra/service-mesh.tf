resource "kubernetes_namespace_v1" "istio-system" {
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istio-base" {
  name      = "istio-base"
  namespace = kubernetes_namespace_v1.istio-system.metadata[0].name

  chart      = "base"
  repository = "https://istio-release.storage.googleapis.com/charts"

  values = ["${file("./configs/istio-base.values.yaml")}"]
}

resource "helm_release" "istiod" {
  name      = "istiod"
  namespace = kubernetes_namespace_v1.istio-system.metadata[0].name

  chart      = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"

  values = ["${file("./configs/istiod.values.yaml")}"]
}
