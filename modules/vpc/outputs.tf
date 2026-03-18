output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "database_subnets" {
  value = module.vpc.database_subnets
}

# database_subnet_group_name output 이름은 사용하는 모듈 버전에 따라 validate 때 다를 수 있다. 만약 에러 나면 output 이름만 모듈 문서 기준으로 맞추면 된다.
output "database_subnet_group_name" {
  value = module.vpc.database_subnet_group_name
}
