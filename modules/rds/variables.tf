variable "identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "db_name" {
  type        = string
  description = "Initial database name"
}

variable "username" {
  type        = string
  description = "Master username"
}

variable "password" {
  type        = string
  description = "Master password"
  sensitive   = true
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Max autoscaled storage in GB"
  default     = 100
}

variable "engine_version" {
  type        = string
  description = "MySQL engine version"
}

variable "family" {
  type        = string
  description = "DB parameter group family"
}

variable "major_engine_version" {
  type        = string
  description = "Major engine version"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Database subnet IDs"
}

variable "admin_security_group_id" {
  type        = string
  description = "Security group ID of SSM admin EC2"
}

variable "eks_node_security_group_id" {
  type        = string
  description = "Security group ID of EKS node group"
}

variable "multi_az" {
  type        = bool
  description = "Enable Multi-AZ"
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Backup retention days"
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot on destroy"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}
