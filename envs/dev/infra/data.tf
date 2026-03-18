# Terraform을 사용하지 않고 만든 Infra structure resource 혹은 다른 곳에서 사용 중인 terraform 코드를 통해 만들어진 resource의 데이터를 갖고 오는데 사용
data "aws_caller_identity" "current" {

}
