########################
# Backend ECR
########################
module "ecr_backend" {
  source = "../../../modules/ecr"

  name = "truve-backend"

  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  force_delete         = true

  # 이미지 10개만 유지
  lifecycle_policy_json = jsonencode({
    rules = [
      {
        "rulePriority" : 1,
        "description" : "Keep last 10 images",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 10
        },
        "action" : {
          "type" : "expire"
        }
      },
    ]
  })

  tags = {
    Project     = "truve"
    Environment = "dev"
    Service     = "backend"
  }
}

########################
# Frontend ECR
########################
module "ecr_frontend" {
  source = "../../../modules/ecr"

  name = "truve-frontend"

  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  force_delete         = true

  # 이미지 10개만 유지 + 7일 지난 태그 없는 이미지 삭제
  lifecycle_policy_json = jsonencode({
    rules = [
      {
        "rulePriority" : 1,
        "description" : "Keep last 10 images",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 10
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })

  tags = {
    Project     = "truve"
    Environment = "dev"
    Service     = "frontend"
  }
}
