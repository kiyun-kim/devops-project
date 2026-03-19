module "vpc" {
  source = "../../../modules/vpc"

  name     = "truve-vpc"
  vpc_cidr = "10.1.0.0/16"

  azs = [
    "ap-northeast-2a",
    "ap-northeast-2c"
  ]

  public_subnets = [
    "10.1.1.0/24",
    "10.1.2.0/24"
  ]

  private_subnets = [
    "10.1.11.0/24",
    "10.1.12.0/24"
  ]

  database_subnets = [
    "10.1.21.0/24",
    "10.1.22.0/24"
  ]

  tags = {
    Project     = "truve"
    Environment = "dev"
    Terraform   = "true"
  }
}
