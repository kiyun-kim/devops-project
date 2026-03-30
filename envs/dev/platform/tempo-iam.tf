############################################
# Tempo용 Assume Role Policy
# EKS Pod Identity를 통해 Tempo Pod가 이 IAM Role을 사용할 수 있게 한다.
############################################
data "aws_iam_policy_document" "tempo_assume_role" {
  statement {
    sid    = "EKSWorkloadPodsAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

############################################
# Tempo가 S3(trace storage)에 접근하기 위한 정책
############################################
data "aws_iam_policy_document" "tempo_s3" {
  statement {
    sid    = "TempoTraceBucketAccess"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging"
    ]

    resources = [
      "arn:aws:s3:::truve-dev-tempo-trace",
      "arn:aws:s3:::truve-dev-tempo-trace/*"
    ]
  }
}

############################################
# Tempo용 IAM Role
############################################
resource "aws_iam_role" "tempo" {
  name               = "${data.terraform_remote_state.infra.outputs.cluster_name}-tempo-role"
  assume_role_policy = data.aws_iam_policy_document.tempo_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${data.terraform_remote_state.infra.outputs.cluster_name}-tempo-role"
    }
  )
}

############################################
# Tempo용 IAM Policy
############################################
resource "aws_iam_policy" "tempo_s3" {
  name   = "${data.terraform_remote_state.infra.outputs.cluster_name}-tempo-s3-policy"
  policy = data.aws_iam_policy_document.tempo_s3.json

  tags = merge(
    local.common_tags,
    {
      Name = "${data.terraform_remote_state.infra.outputs.cluster_name}-tempo-s3-policy"
    }
  )
}

############################################
# Tempo IAM Role에 S3 정책 연결
############################################
resource "aws_iam_role_policy_attachment" "tempo_s3" {
  role       = aws_iam_role.tempo.name
  policy_arn = aws_iam_policy.tempo_s3.arn
}

############################################
# Tempo ServiceAccount와 IAM Role 연결
# Helm chart values에서 serviceAccount.name: tempo 로 맞춰야 한다.
############################################
resource "aws_eks_pod_identity_association" "tempo" {
  cluster_name    = data.terraform_remote_state.infra.outputs.cluster_name
  namespace       = "observability"
  service_account = "tempo"
  role_arn        = aws_iam_role.tempo.arn

  depends_on = [
    aws_iam_role_policy_attachment.tempo_s3
  ]
}
