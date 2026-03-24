terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0, < 6.0.0"
    }
  }

  backend "s3" {
    bucket = "truve-dev-tfstate"
    key    = "dev/infra/terraform.tfstate"
    region = "ap-northeast-2"
    # dynamodb_table = "truve-dev-tf-lock"
    use_lockfile = true
    encrypt      = true
    profile      = "truve-admin"
  }
}
