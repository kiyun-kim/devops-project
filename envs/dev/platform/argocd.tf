resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.16"
  create_namespace = false

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode({
      nodeSelector = {
        workload = "system"
      }

      tolerations = [
        {
          key      = "workload"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "helm_release" "argocd_image_updater" {
  name             = "argocd-image-updater"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-image-updater"
  version          = "1.0.5"
  create_namespace = false

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode({
      nodeSelector = {
        workload = "system"
      }

      tolerations = [
        {
          key      = "workload"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.argocd,
    helm_release.argocd
  ]
}
