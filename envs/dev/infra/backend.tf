# tfstate를 저장할 backend 설정
terraform {
  backend "s3" {
    bucket         = "truve-tfstate-bucket"
    key            = "envs/dev/infra/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true          # S3 암호화
    profile        = "truve-admin" # AWS CLI 프로파일 지정
  }
}
