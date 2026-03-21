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

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.control_plane_subnet_ids

  # CloudWatch 로그 사용 안함 (Loki 등 외부 스택 사용 예정)
  create_cloudwatch_log_group = false

  cluster_addons = {
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
  cluster_endpoint_public_access = true

  # 클러스터 생성한 IAM 사용자를 자동 admin으로 등록
  enable_cluster_creator_admin_permissions = true

  # EKS Access Entry 기반 권한 관리
  # cluster creator: 최초 클러스터 생성 IAM 주체를 admin으로 등록
  # ops EC2: SSM으로 접속한 운영용 EC2에서 kubectl/helm 사용 가능하도록 admin 권한 부여
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
