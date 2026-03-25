############################################
# Security Group
# ops-ec2가 SSM 기반으로만 접속되므로 인바운드는 열지 않고, 아웃바운드만 전체 허용한다.
############################################
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-sg-"
  description = "Security group for ${var.name} SSM instance"
  vpc_id      = var.vpc_id

  # SSM 접속만 사용하므로 인바운드는 열지 않음
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-sg"
    }
  )
}

############################################
# IAM Role
# ops-ec2 인스턴스가 사용할 기본 IAM Role이다.
############################################
resource "aws_iam_role" "this" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

############################################
# SSM Core Policy
# Session Manager를 통한 접속 및 기본 SSM 기능에 필요하다.
############################################
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# AdministratorAccess Policy
# ops-ec2에서 Terraform 실행 시 필요한 AWS 리소스 생성/수정 권한을 빠르게 확보하기 위해 관리자 권한을 연결한다.
############################################
resource "aws_iam_role_policy_attachment" "administrator_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################################
# Ops Read Access Policy
# AdministratorAccess 사용 시 완전히 중복되므로 주석 처리한다.
# 최소 권한으로 다시 줄일 때 필요하면 복구해서 사용하면 된다.
############################################
# resource "aws_iam_role_policy" "ops_access" {
#   name = "${var.name}-ops-access"
#   role = aws_iam_role.this.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:DescribeCluster",
#           "ec2:DescribeInstances",
#           "ec2:DescribeSubnets",
#           "ec2:DescribeSecurityGroups",
#           "ec2:DescribeVpcs",
#           "ec2:DescribeRouteTables",
#           "ec2:DescribeNatGateways",
#           "ec2:DescribeInternetGateways",
#           "route53:GetHostedZone",
#           "route53:ListHostedZones",
#           "route53:ListResourceRecordSets",
#           "elasticloadbalancing:DescribeLoadBalancers",
#           "elasticloadbalancing:DescribeLoadBalancerAttributes",
#           "elasticloadbalancing:DescribeListeners",
#           "elasticloadbalancing:DescribeTargetGroups",
#           "elasticloadbalancing:DescribeTags",
#           "autoscaling:DescribeAutoScalingGroups"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

############################################
# Route53 Change Policy
# AdministratorAccess 사용 시 완전히 중복되므로 주석 처리한다.
# 최소 권한 운영으로 전환할 때 Route53 변경 권한만 따로 분리해서
# 다시 사용할 수 있다.
############################################
# resource "aws_iam_policy" "ops_ec2_route53_change" {
#   name        = "${var.name}-route53-change"
#   description = "Allow Route53 record changes for Terraform on ops EC2"
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "Route53ChangeRecordSets"
#         Effect = "Allow"
#         Action = [
#           "route53:ChangeResourceRecordSets"
#         ]
#         Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
#       },
#       {
#         Sid    = "Route53ReadRecordSets"
#         Effect = "Allow"
#         Action = [
#           "route53:GetHostedZone",
#           "route53:ListResourceRecordSets"
#         ]
#         Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
#       },
#       {
#         Sid    = "Route53GetChange"
#         Effect = "Allow"
#         Action = [
#           "route53:GetChange"
#         ]
#         Resource = "arn:aws:route53:::change/*"
#       }
#     ]
#   })
# }
#
# resource "aws_iam_role_policy_attachment" "ops_ec2_route53_change" {
#   role       = aws_iam_role.this.name
#   policy_arn = aws_iam_policy.ops_ec2_route53_change.arn
# }

############################################
# Terraform Backend Access Policy
# AdministratorAccess 사용 시 완전히 중복되므로 주석 처리한다.
# 최소 권한 운영으로 전환할 때 S3 backend 접근 권한만 따로 분리해서
# 다시 사용할 수 있다.
############################################
# resource "aws_iam_role_policy" "terraform_backend_access" {
#   name = "${var.name}-terraform-backend-access"
#   role = aws_iam_role.this.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "TerraformStateBucketList"
#         Effect = "Allow"
#         Action = [
#           "s3:ListBucket",
#           "s3:GetBucketLocation"
#         ]
#         Resource = "arn:aws:s3:::truve-dev-tfstate"
#       },
#       {
#         Sid    = "TerraformStateObjectAccess"
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject"
#         ]
#         Resource = "arn:aws:s3:::truve-dev-tfstate/*"
#       }
#     ]
#   })
# }

############################################
# Instance Profile
# EC2 인스턴스에 IAM Role을 연결하기 위한 Instance Profile이다.
############################################
resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.this.name

  tags = var.tags
}

############################################
# Latest Amazon Linux 2023 AMI
# ami_id를 따로 주지 않으면 최신 AL2023 AMI를 SSM Parameter Store에서 조회한다.
############################################
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

############################################
# EC2 Instance
# SSM 기반 운영용 ops-ec2 인스턴스를 생성한다.
############################################
resource "aws_instance" "this" {
  ami                         = coalesce(var.ami_id, data.aws_ssm_parameter.al2023_ami.value)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip_address
  user_data                   = var.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
