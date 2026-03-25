module "eks" {
  source = "../../../modules/eks-managed"

  cluster_name    = "truve-eks-dev"
  cluster_version = "1.34"

  # VPC 모듈 output 참조
  # module.vpc 값을 사용하므로 VPC가 먼저 생성된 뒤 EKS가 생성됨
  vpc_id = module.vpc.vpc_id

  # Worker Node가 들어갈 서브넷
  # 일반적으로 private subnet 사용
  subnet_ids = module.vpc.private_subnets

  # Control Plane ENI가 들어갈 서브넷
  # 보통 private subnet 사용
  control_plane_subnet_ids = module.vpc.private_subnets

  ops_ec2_security_group_id = module.ops_ec2.security_group_id

  ################################################
  # EKS Managed Node Group 설정
  # 분리 기준
  #   - system: 클러스터 운영용 (ALB Controller, Karpenter Controller, CoreDNS 등)
  #   - app: 기본 애플리케이션 워크로드용
  #   - cicd: CI/CD 워크로드 전용
  #   - monitoring: Prometheus/Grafana/Loki 등
  #
  # 운영 의도
  #   - Karpenter Controller 자체는 system 노드그룹에서 고정 운영
  #   - app 노드그룹은 기본 애플리케이션 수용용으로 최소 구성
  #   - 실제 scale-out 테스트는 KEDA가 Pod를 늘리고,
  #     부족한 노드는 Karpenter가 별도 NodePool로 확장하는 구조를 권장
  ################################################
  node_groups = {
    system = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["t4g.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload = "system"
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }

    app = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3a.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 1

      labels = {
        workload  = "app"
        autoscale = "karpenter"
      }

      taints = [
        {
          key    = "workload"
          value  = "app"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }

    cicd = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 0
      max_size     = 2
      desired_size = 0

      labels = {
        workload = "cicd"
      }

      taints = [
        {
          key    = "workload"
          value  = "cicd"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }

    monitoring = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload = "monitoring"
      }

      taints = [
        {
          key    = "workload"
          value  = "monitoring"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  ops_ec2_role_arn = module.ops_ec2.iam_role_arn

  tags = {
    Project     = "truve"
    Environment = "dev"
    Terraform   = "true"
  }
}
