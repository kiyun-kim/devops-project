data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket         = "truve-dev-tfstate"
    key            = "envs/dev/infra/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "truve-dev-tf-lock"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

data "aws_eks_cluster" "this" {
  name = "truve-eks-dev"
}

data "aws_eks_cluster_auth" "this" {
  name = "truve-eks-dev"
}
