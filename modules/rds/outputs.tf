output "db_instance_id" {
  value = module.rds.db_instance_identifier
}

output "db_instance_endpoint" {
  value = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  value = module.rds.db_instance_address
}

output "db_instance_port" {
  value = module.rds.db_instance_port
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
