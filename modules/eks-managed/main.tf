############################################
# EBS CSI Driver용 Assume Role Policy
# EKS Pod Identity를 통해 EBS CSI Controller가 이 IAM Role을 사용할 수 있게 한다.
############################################
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    sid    = "EKSAddonPodsAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

############################################
# EBS CSI Driver용 IAM Role
# aws-ebs-csi-driver addon이 EBS 볼륨 생성/부착 권한을 사용하기 위한 역할
############################################
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.cluster_name}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver-role"
    }
  )
}

############################################
# EBS CSI Driver 정책 연결
# AWS 관리형 AmazonEBSCSIDriverPolicy를 연결한다.
############################################
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

############################################
# EKS Cluster
############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # Karpenter가 노드 생성 시 참조할 node security group 태그
  node_security_group_tags = var.node_security_group_tags

  # CloudWatch 로그 사용 안함 (Loki 등 외부 스택 사용 예정)
  create_cloudwatch_log_group = false

  cluster_addons = {
    # Kubernetes 내부 DNS
    coredns = {
      most_recent = true # EKS 버전에 맞는 최신 버전 자동 선택
    }

    # Pod Identity Agent (IRSA 대신 사용)
    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true # 노드 생성 전에 먼저 설치
    }

    # Kubernetes 네트워크 라우팅
    kube-proxy = {
      most_recent = true
    }

    # Pod에 AWS ENI를 붙여주는 네트워크 플러그인
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

    # EBS CSI Driver
    aws-ebs-csi-driver = {
      most_recent = true

      pod_identity_association = [
        {
          role_arn        = aws_iam_role.ebs_csi_driver.arn
          service_account = "ebs-csi-controller-sa"
        }
      ]
    }
  }

  # API 서버 퍼블릭 접근 허용
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_security_group_additional_rules = {
    ops_ec2_https = {
      description              = "Allow ops EC2 to access EKS API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = var.ops_ec2_security_group_id
    }
  }

  # 클러스터 생성한 IAM 사용자를 자동 admin으로 등록
  enable_cluster_creator_admin_permissions = true

  # EKS Access Entry 기반 권한 관리
  access_entries = merge(
    {
      ops_ec2 = {
        principal_arn = var.ops_ec2_role_arn

        policy_associations = {
          cluster_admin = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    },
    var.access_entries
  )

  eks_managed_node_groups = var.node_groups

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}
