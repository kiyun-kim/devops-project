############################################
# Karpenter (Pod Identity + Helm values)
############################################
locals {
  karpenter_namespace          = "karpenter"
  karpenter_service_account    = "karpenter"
  karpenter_chart_version      = "1.2.1"
  karpenter_node_role_name     = "${local.project_name}-${local.environment}-karpenter-node-role"
  karpenter_controller_role    = "${local.project_name}-${local.environment}-karpenter-controller-role"
  karpenter_interruption_queue = "${local.project_name}-${local.environment}-karpenter-interruption"
}

############################################
# Namespace
############################################
resource "kubernetes_namespace_v1" "karpenter" {
  metadata {
    name = local.karpenter_namespace
  }
}

############################################
# SQS Queue for interruption handling
############################################
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = local.karpenter_interruption_queue
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = {
    Name        = local.karpenter_interruption_queue
    Environment = local.environment
    Terraform   = "true"
  }
}

############################################
# EventBridge -> SQS
# interruption / rebalance / state-change
############################################
resource "aws_cloudwatch_event_rule" "karpenter_health_events" {
  name        = "${local.karpenter_interruption_queue}-health"
  description = "Karpenter interruption handling - AWS Health events"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_spot_interruptions" {
  name        = "${local.karpenter_interruption_queue}-spot"
  description = "Karpenter interruption handling - EC2 Spot interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${local.karpenter_interruption_queue}-rebalance"
  description = "Karpenter interruption handling - EC2 rebalance"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_rule" "karpenter_state_change" {
  name        = "${local.karpenter_interruption_queue}-state-change"
  description = "Karpenter interruption handling - EC2 state change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_health_events" {
  rule      = aws_cloudwatch_event_rule.karpenter_health_events.name
  target_id = "KarpenterHealthToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruptions" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruptions.name
  target_id = "KarpenterSpotToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterRebalanceToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "karpenter_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_state_change.name
  target_id = "KarpenterStateChangeToSQS"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

data "aws_iam_policy_document" "karpenter_interruption_queue" {
  statement {
    sid    = "AllowEventBridgeSendMessage"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.karpenter_interruption.arn
    ]
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy    = data.aws_iam_policy_document.karpenter_interruption_queue.json
}

############################################
# Karpenter Node Role
# EC2NodeClass에서 사용할 role
############################################
resource "aws_iam_role" "karpenter_node" {
  name = local.karpenter_node_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = local.karpenter_node_role_name
    Environment = local.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

############################################
# Karpenter Controller Role (Pod Identity)
############################################
resource "aws_iam_role" "karpenter_controller" {
  name = local.karpenter_controller_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name        = local.karpenter_controller_role
    Environment = local.environment
    Terraform   = "true"
  }
}

# 초안 단계라 권한을 넓게 잡은 버전
# 실사용 전에는 최소권한으로 줄이는 작업 권장
data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "KarpenterEC2"
    effect = "Allow"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeVpcs",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "ec2:RunInstances",
      "ec2:TerminateInstances"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KarpenterPricingAndSSM"
    effect = "Allow"
    actions = [
      "pricing:GetProducts",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KarpenterPassNodeRole"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.karpenter_node.arn
    ]
  }

  # 추가된 Instance Profile 관리 권한
  statement {
    sid    = "KarpenterInstanceProfileManagement"
    effect = "Allow"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KarpenterDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [
      data.aws_eks_cluster.this.arn
    ]
  }

  statement {
    sid    = "KarpenterInterruptionQueue"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]
    resources = [
      aws_sqs_queue.karpenter_interruption.arn
    ]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name   = "${local.karpenter_controller_role}-policy"
  policy = data.aws_iam_policy_document.karpenter_controller.json

}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

############################################
# Pod Identity Association
############################################
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = data.aws_eks_cluster.this.name
  namespace       = local.karpenter_namespace
  service_account = local.karpenter_service_account
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [
    kubernetes_namespace_v1.karpenter
  ]
}

############################################
# Helm Release
############################################
resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = local.karpenter_chart_version
  namespace        = local.karpenter_namespace
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      replicas = 1

      serviceAccount = {
        name = local.karpenter_service_account
      }

      settings = {
        clusterName       = data.aws_eks_cluster.this.name
        interruptionQueue = aws_sqs_queue.karpenter_interruption.name
      }

      controller = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.karpenter,
    aws_eks_pod_identity_association.karpenter
  ]
}
