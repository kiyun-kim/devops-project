module "ec2_ssm" {
  source = "../../../modules/ec2-ssm"

  name   = "dev-ssm-ec2"
  vpc_id = module.vpc.vpc_id

  # 퍼블릭 서브넷 1개 선택
  subnet_id = module.vpc.private_subnets[0]

  instance_type               = "t3.micro"
  associate_public_ip_address = false

  tags = {
    Project     = "devops-project"
    Environment = "dev"
    Terraform   = "true"
  }
}
