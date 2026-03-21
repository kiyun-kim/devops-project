variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Worker node subnets"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Control plane subnets"
  type        = list(string)
}

variable "node_groups" {
  description = "EKS managed node groups"
  type        = any
}

variable "ops_ec2_role_arn" {
  description = "IAM role ARN for ops EC2 to access EKS via Access Entry"
  type        = string
}

variable "access_entries" {
  description = "Additional EKS access entries"
  type        = map(any)
  default     = {}
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}
