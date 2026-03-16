output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of EC2"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP of EC2"
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to EC2"
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "IAM role name for EC2"
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "IAM role ARN for ops EC2"
  value       = aws_iam_role.this.arn
}
