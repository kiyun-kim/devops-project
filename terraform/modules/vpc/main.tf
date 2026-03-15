module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = var.name
  cidr = var.vpc_cidr

  azs             = var.azs             # Availability Zones
  public_subnets  = var.public_subnets  # Public Subnet CIDR 블록
  private_subnets = var.private_subnets # Private Subnet CIDR 블록

  enable_nat_gateway = true # NAT Gateway 활성화
  single_nat_gateway = true # 단일 NAT Gateway 설정

  enable_dns_hostnames = true # DNS 호스트 이름 활성화
  enable_dns_support   = true # DNS 지원 활성화

  tags = var.tags

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Type                     = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Type                              = "private"
  }
}
