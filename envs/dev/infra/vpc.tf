module "vpc" {
  source = "../../../modules/vpc"

  name     = "truve-vpc"
  vpc_cidr = "10.0.0.0/16"

  azs = [
    "ap-northeast-2a",
    "ap-northeast-2c"
  ]

  public_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  private_subnets = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]

  database_subnets = [
    "10.0.21.0/24",
    "10.0.22.0/24"
  ]

  tags = {
    Project     = "truve"
    Environment = "dev"
    Terraform   = "true"
  }
}
