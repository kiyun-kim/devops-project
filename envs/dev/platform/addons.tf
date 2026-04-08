locals {
  cluster_name = data.terraform_remote_state.infra.outputs.cluster_name
  vpc_id       = data.terraform_remote_state.infra.outputs.vpc_id
  aws_region   = "ap-northeast-2"
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = "kube-system"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  version          = "3.11.0" # 버전 고정
  create_namespace = false

  timeout         = 600  # 초기 클러스터 상태나 이미지 pull 속도에 따라 설치 시간이 걸릴 수 있어 충분히 긴 timeout 설정
  atomic          = true # 설치/업그레이드 실패 시 helms release를 자동으로 롤백
  cleanup_on_fail = true # 실패 시 불완전 리소스 정리에 도움 됨
}

###############################################
# AWS Load Balancer Controller
# ALB/NLB를 Kubernetes 서비스에 연결해주는 컨트롤러
###############################################
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "3.1.0"
  create_namespace = false

  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [
    yamlencode({
      clusterName = local.cluster_name
      region      = local.aws_region
      vpcId       = local.vpc_id

      replicaCount = 1

      serviceAccount = {
        # helm이 서비스 어카운트를 생성하도록 설정
        # platform에서 Helm이 SA 생성, infra에선 Pod Identity Association만 이름 기준으로 관리
        create = true
        name   = "aws-load-balancer-controller"
      }
    })
  ]
}
