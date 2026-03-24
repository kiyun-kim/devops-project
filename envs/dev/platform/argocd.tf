resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.16"
  create_namespace = false

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode({
      # 노드 라벨 키 system이 존재하는 노드에만 ArgoCD 컴포넌트를 스케줄링하도록 설정
      global = {
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [
                {
                  matchExpressions = [
                    {
                      key      = "system"
                      operator = "Exists"
                    }
                  ]
                }
              ]
            }
          }
        }
      }

      configs = {
        params = {
          "server.insecure" = true # 초기 구축 단계에서 ALB/Ingress 붙이기 전에 포트포워드나 내부 접근으로 확인하기 편하다.
        }
      }

      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}
