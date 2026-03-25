locals {
  project_name = "truve"
  environment  = "dev"

  argocd_acm_certificate_arn = "arn:aws:acm:ap-northeast-2:599476212908:certificate/c777a244-2261-47b1-aea0-0f68c9fb5249"
  argocd_alb_name            = "argocd-alb"
  argocd_host                = "argocd.truve.site"

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    Terraform   = "true"
  }
}
