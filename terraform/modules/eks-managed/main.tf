module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  addons = {
    # Kubernetes 내부 DNS
    coredns = {
      most_recent = true # EKS 버전에 맞는 최신 버전 자동 선택
    }

    # IRSA 대신 사용하는 새로운 IAM 연결 방식
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true # 노드 생성 전에 먼저 설치
    }

    # Kubernetes 네트워크 라우팅 담당
    kube-proxy = {
      most_recent = true
    }

    # Pod에 AWS ENI를 붙여주는 네트워크 플러그인
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

    # EBS 볼륨을 Pod에 마운트할 수 있게 하는 CSI Driver
    aws-ebs-csi-driver = {
      most_recent    = true
      before_compute = true
    }
  }

  # API 서버 퍼블릭 접근 허용
  endpoint_public_access = true

  # 클러스터 생성한 IAM 사용자를 자동 admin으로 등록
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  eks_managed_node_groups = var.node_groups

  tags = var.tags
}
