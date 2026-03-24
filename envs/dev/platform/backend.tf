# tfstate를 저장할 backend 설정
terraform {
  backend "s3" {
    bucket = "truve-dev-tfstate"
    key    = "dev/platform/terraform.tfstate"
    region = "ap-northeast-2"
    # dynamodb_table = "truve-dev-tf-lock"
    use_lockfile = true
    encrypt      = true
    profile      = "truve-admin"
  }
}
