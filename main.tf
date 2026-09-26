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
  key            = "Purpose"
  region         = "ap-south-2"
  use_lockfile    = true
  encrypt        = true
}
}

provider "aws" {
  region = "ap-south-2"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "s3_terraform_state" {
  bucket = "terraform-state-bucket-${data.aws_caller_identity.current.account_id}"
  tags = {
    Purpose = "tf State"
  }
}
