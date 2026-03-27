module "eks" {
  source = "../../../modules/eks-managed"

  cluster_name    = "truve-eks-dev"
  cluster_version = "1.34"

  # VPC 모듈 output 참조
  vpc_id = module.vpc.vpc_id # module.vpc 값을 사용하므로 VPC가 먼저 생성된 뒤 EKS가 생성됨

  # Worker Node가 들어갈 서브넷
  subnet_ids = module.vpc.private_subnets

  # Control Plane ENI가 들어갈 서브넷
  control_plane_subnet_ids = module.vpc.private_subnets

  ops_ec2_security_group_id = module.ops_ec2.security_group_id
  ops_ec2_role_arn          = module.ops_ec2.iam_role_arn

  node_security_group_tags = {
    "karpenter.sh/discovery" = "truve-eks-dev" # local.cluster_name
  }

  ################################################
  # EKS Managed Node Group 설정
  # 분리 기준
  #   - system: 클러스터 운영용 (ALB Controller, Karpenter Controller, CoreDNS 등)
  #   - cicd: CI/CD 워크로드 전용
  #   - monitoring: Prometheus/Grafana/Loki 등 운영 관측용
  #   - kafka: Stateful 메시징 브로커 전용
  #   - redis: Stateful 캐시/인메모리 저장소 전용
  #
  # 운영 의도
  #   - Karpenter Controller 자체는 system 노드그룹에서 고정 운영
  #   - app 워크로드는 별도 Managed Node Group 대신, Karpenter NodePool + KEDA 조합으로 유연하게 확장
  #   - Kafka/Redis는 Stateful 특성상 리스크가 있으므로 Managed Node Group으로 고정 운영
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

      taints = [
        {
          key    = "workload"
          value  = "system"
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

    messaging = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = ["m6g.large"]
      capacity_type  = "ON_DEMAND"

      min_size     = 3
      max_size     = 3
      desired_size = 3

      labels = {
        workload = "messaging"
      }

      taints = [
        {
          key    = "workload"
          value  = "messaging"
          effect = "NO_SCHEDULE"
        }
      ]

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = {
    Project     = "truve"
    Environment = "dev"
    Terraform   = "true"
  }
}
