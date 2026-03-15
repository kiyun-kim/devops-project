data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket         = "devops-prj-tfstate"
    key            = "envs/dev/infra/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "devops-prj-tfstate-lock"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}
