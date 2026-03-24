variable "argocd_host" {
  description = "ArgoCD hostname"
  type        = string
}

variable "argocd_acm_certificate_arn" {
  description = "ACM certificate ARN for ArgoCD ingress"
  type        = string
}

variable "argocd_alb_name" {
  description = "ALB name for ArgoCD"
  type        = string
}
