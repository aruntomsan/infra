terraform {
  required_version = "v1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
  backend "s3" {
  bucket         = "terraform-state-bucket-778477254970"
  key            = "terraform.tfstate"
  region         = "ap-south-2"
  use_lockfile    = true
  encrypt        = true
}
}

provider "aws" {
  region = "ap-south-2"
}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "gha" {
  name = "tf_s3_state"
}

resource "aws_iam_role_policy" "tf_ecr" {
  name = "tf_ecr_policy"
  role = data.aws_iam_role.gha.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageServiceRepositories"
      Effect = "Allow"
      Action = [
        "ecr:CreateRepository", "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:ListTagsForResource", "ecr:TagResource", "ecr:UntagResource",
        "ecr:PutImageTagMutability", "ecr:PutImageScanningConfiguration",
        "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy"
      ]
      Resource = "arn:aws:ecr:ap-south-2:${data.aws_caller_identity.current.account_id}:repository/*"
    }]
  })
}


variable "list_of_services" {
  type    = set(string)
  default = [
  "adservice",
  "cartservice",
  "checkoutservice",
  "currencyservice",
  "emailservice",
  "frontend",
  "loadgenerator",
  "paymentservice",
  "productcatalogservice",
  "recommendationservice",
  "shippingservice",
  "shoppingassistantservice"
]  
}

resource "aws_ecr_repository" "repo_for_microservices" {
  for_each = var.list_of_services
  name     = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

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
