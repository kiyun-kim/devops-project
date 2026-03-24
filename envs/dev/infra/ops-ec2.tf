module "ops_ec2" {
  source = "../../../modules/ops-ec2"

  name                        = "ops-ec2"
  vpc_id                      = module.vpc.vpc_id
  subnet_id                   = module.vpc.private_subnets[0] # 퍼블릭 서브넷 1개 선택
  instance_type               = "t3a.medium"
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y \
      git \
      jq \
      wget \
      tree \
      unzip \
      tar \
      gzip \
      bash-completion

    # AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install --update

    # kubectl
    KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
    curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Terraform
    TERRAFORM_VERSION="1.11.4"
    curl -L -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
    unzip -q /tmp/terraform.zip -d /usr/local/bin
    chmod +x /usr/local/bin/terraform

    # ec2-user sudo
    echo "ec2-user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/ec2-user
    chmod 440 /etc/sudoers.d/ec2-user

    # ssm-user sudo
    echo "ssm-user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/ssm-user
    chmod 440 /etc/sudoers.d/ssm-user

    # 공통 profile
    cat <<'PROFILE' >/etc/profile.d/ops-tools.sh
    export PATH=$PATH:/usr/local/bin
    export AWS_REGION=ap-northeast-2
    alias k=kubectl
    PROFILE

    # kubeconfig helper
    cat <<'SCRIPT' >/usr/local/bin/setup-kubeconfig
    #!/usr/bin/env bash
    set -euo pipefail

    AWS_REGION="$${AWS_REGION:-ap-northeast-2}"
    CLUSTER_NAME="$${1:-truve-eks-dev}"

    echo "Updating kubeconfig for cluster: $${CLUSTER_NAME}"
    aws eks update-kubeconfig \
      --region "$AWS_REGION" \
      --name "$CLUSTER_NAME"

    echo
    kubectl config current-context
    echo
    kubectl get nodes -o wide
    SCRIPT

    chmod +x /usr/local/bin/setup-kubeconfig

    # workspace
    mkdir -p /home/ec2-user/workspace
    chown -R ec2-user:ec2-user /home/ec2-user/workspace
  EOF

  tags = {
    Project     = "truve"
    Environment = "dev"
    Terraform   = "true"
  }
}
