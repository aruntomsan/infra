terraform {
  required_version = "v1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
  backend "s3" {
  bucket         = "terraform-state-bucket-dev-778477254970"
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

module "ecr" {
  source = "../../modules/ecr_for_mvcs"
  env    = "dev"
}