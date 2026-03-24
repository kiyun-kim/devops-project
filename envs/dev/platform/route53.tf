data "aws_lb" "argocd" {
  name = var.argocd_alb_name

  depends_on = [
    kubernetes_ingress_v1.argocd
  ]
}

resource "aws_route53_record" "argocd" {
  zone_id = "Z09263044C7J602NPFIC"
  name    = var.argocd_host
  type    = "A"

  alias {
    name                   = data.aws_lb.argocd.dns_name
    zone_id                = data.aws_lb.argocd.zone_id
    evaluate_target_health = true
  }
}
