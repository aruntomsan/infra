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
}
