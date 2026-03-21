resource "aws_security_group" "rds" {
  name        = "${var.identifier}-sg"
  description = "Security group for MySQL RDS"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_admin" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.admin_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Allow MySQL from SSM admin EC2"
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_eks" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.eks_node_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Allow MySQL from EKS nodes"
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.8.0"

  identifier = var.identifier

  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t4g.micro"
  allocated_storage     = "20"
  max_allocated_storage = "100"

  db_name  = var.db_name
  username = var.username

  # 비밀번호를 AWS Secrets Manager 자동관리 방식으로 안 쓰겠다는 뜻
  manage_master_user_password = false
  password                    = var.password

  port     = 3306
  multi_az = var.multi_az

  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids

  vpc_security_group_ids = [aws_security_group.rds.id]

  create_db_parameter_group = true
  family                    = "mysql8.0"

  create_db_option_group = true
  # MySQL 8.0 버전에 맞는 옵션 그룹이 자동 생성되도록 major_engine_version만 지정
  major_engine_version = "8.0"

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-06:00"
  maintenance_window      = "Mon:00:00-Mon:03:00"

  # 삭제 보호 비활성화 (default false)
  deletion_protection = var.deletion_protection
  # destroy 시 final snapshot 없이 바로 삭제 (default true)
  skip_final_snapshot = var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  publicly_accessible = false
  storage_encrypted   = true

  tags = merge(var.tags, {
    Name = var.identifier
  })
}
