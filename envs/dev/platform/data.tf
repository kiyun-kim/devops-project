data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket  = "truve-dev-tfstate"
    key     = "dev/infra/terraform.tfstate"
    region  = "ap-northeast-2"
    encrypt = true
    # dynamodb_table = "truve-dev-tf-lock"
    use_lockfile = true
    # profile      = "truve-admin"
  }
}

data "aws_eks_cluster" "this" {
  name = "truve-eks-dev"
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}
