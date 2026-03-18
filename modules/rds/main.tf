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
  version = "7.0.0"

  identifier = var.identifier

  engine               = "mysql"
  engine_version       = var.engine_version
  family               = var.family
  major_engine_version = var.major_engine_version

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = false        # 비밀번호를 AWS Secrets Manager 자동관리 방식으로 안 쓰겠다는 뜻
  password_wo                 = var.password # 직접 넣은 비밀번호 사용
  password_wo_version         = 1            # 비밀번호 버전, RDS 모듈에서 관리하는 비밀번호가 아니므로 버전은 1로 고정
  port                        = 3306

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot

  create_db_subnet_group = true
  subnet_ids             = var.subnet_ids

  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  storage_encrypted   = true

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  tags = merge(var.tags, {
    Name = var.identifier
  })
}
