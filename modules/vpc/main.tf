module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = var.name
  cidr = var.vpc_cidr

  azs              = var.azs              # Availability Zones
  public_subnets   = var.public_subnets   # Public Subnet CIDR 블록
  private_subnets  = var.private_subnets  # Private Subnet CIDR 블록
  database_subnets = var.database_subnets # Database Subnet CIDR 블록

  enable_nat_gateway = true # NAT Gateway 활성화
  single_nat_gateway = true # 단일 NAT Gateway 설정

  enable_dns_hostnames = true # DNS 호스트 이름 활성화
  enable_dns_support   = true # DNS 지원 활성화

  create_database_subnet_group           = true  # Database Subnet 그룹 생성 여부
  create_database_subnet_route_table     = true  # Database Subnet 전용 라우팅 테이블 생성 여부
  create_database_internet_gateway_route = false # Database Subnet에서 IGW로의 라우팅 생성 여부 (보안상 권장하지 않음)

  tags = var.tags

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Type                     = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Type                              = "private"
  }

  database_subnet_tags = {
    Type = "database"
  }
}
