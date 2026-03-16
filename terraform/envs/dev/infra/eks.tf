module "eks" {
  source = "../../../modules/eks-managed"

  cluster_name       = "dev-eks-v2"
  kubernetes_version = "1.34"

  # VPC 모듈 output 참조
  # module.vpc 값을 사용하므로 VPC가 먼저 생성된 뒤 EKS가 생성됨
  vpc_id = module.vpc.vpc_id

  # Worker Node가 들어갈 서브넷
  # 일반적으로 private subnet 사용
  subnet_ids = module.vpc.private_subnets

  # Control Plane ENI가 들어갈 서브넷
  # 보통 private subnet 사용
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Group 설정
  node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      ami_type = "AL2023_x86_64_STANDARD"

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  ops_ec2_role_arn = module.ops_ec2.iam_role_arn


  tags = {
    Project     = "devops-project"
    Environment = "dev"
    Terraform   = "true"
  }
}
