resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"

    annotations = {
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = "[{\"HTTP\":80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"       = "443"
      "alb.ingress.kubernetes.io/certificate-arn"    = var.argocd_acm_certificate_arn
      "alb.ingress.kubernetes.io/backend-protocol"   = "HTTPS"
      "alb.ingress.kubernetes.io/healthcheck-path"   = "/healthz"
      "alb.ingress.kubernetes.io/healthcheck-port"   = "traffic-port"
      "alb.ingress.kubernetes.io/success-codes"      = "200-399"
      "alb.ingress.kubernetes.io/load-balancer-name" = var.argocd_alb_name
      "alb.ingress.kubernetes.io/group.name"         = var.argocd_alb_name
      "alb.ingress.kubernetes.io/group.order"        = "10"
    }
  }

  spec {
    rule {
      host = var.argocd_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}
