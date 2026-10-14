resource "aws_ecr_repository" "repo_for_microservices" {
  for_each = var.list_of_services
  name = "${var.env}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete = true
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.repo_for_microservices

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description   = "Expire untagged images after 7 days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description   = "Keep the last 10 tagged images"

        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}