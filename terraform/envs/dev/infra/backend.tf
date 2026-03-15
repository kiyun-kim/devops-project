# tfstate를 저장할 backend 설정
terraform {
  backend "s3" {
    bucket         = "devops-prj-tfstate"
    key            = "envs/dev/infra/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    profile        = "devops"
  }
}
