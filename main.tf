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
