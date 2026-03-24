data "aws_route53_zone" "this" {
  name         = var.route53_zone_name
  private_zone = false
}

data "aws_lb" "argocd" {
  name = var.argocd_alb_name

  depends_on = [
    kubernetes_ingress_v1.argocd
  ]
}

resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.argocd_host
  type    = "A"

  alias {
    name                   = data.aws_lb.argocd.dns_name
    zone_id                = data.aws_lb.argocd.zone_id
    evaluate_target_health = true
  }
}
