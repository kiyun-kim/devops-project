module "vpc" {
  source  = "terraform-aws-modules/vpc/aws" # 사용할 Module의 경로
  version = "6.0.1"                         # Module의 버전

  name = var.name     # VPC의 이름
  cidr = var.vpc_cidr # VPC의 CIDR 블록

  azs             = var.azs             # Availability Zones
  public_subnets  = var.public_subnets  # Public Subnet CIDR 블록
  private_subnets = var.private_subnets # Private Subnet CIDR 블록

  enable_nat_gateway = true # NAT Gateway 활성화
  single_nat_gateway = true # 단일 NAT Gateway 설정

  enable_dns_hostnames = true # DNS 호스트 이름 활성화
  enable_dns_support   = true # DNS 지원 활성화

  tags = var.tags

  public_subnet_tags = {
    Type = "public"
  }

  private_subnet_tags = {
    Type = "private"
  }
}
