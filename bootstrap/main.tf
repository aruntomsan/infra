#This will not be run using a CI/CD tool. 
#This will be run manually using an SSO login directly from the CLI. 
#Once this infra is up and running, we set aside this configuration file 
#And import this infrastructure into the main configuration file & state. 
terraform {
  required_version = "v1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }
}

provider "aws" {
  region = "ap-south-2"
  profile = "bootstrap-admin"
}

data "aws_caller_identity" "current" {}

locals {
  envs = toset(["dev"]) #For now, we are only creating one environment. In future, we can add more environments like prod, stage, etc.
  account_id = data.aws_caller_identity.current.account_id
  bucket_arns = [
  for bucket in aws_s3_bucket.s3_terraform_state : bucket.arn
  ]
  gh_owner    = "aruntomsan"
  gh_owner_id = 111147301

  gha_repos = {
    "infra"            = 1389184781
    "adservice"        = 1387353019
    "cartservice"      = 1387357358
    "catalogservice"   = 1387368626
    "checkoutservice"  = 1387359561
    "currencyservice"  = 1387361273
    "emailservice"     = 1387362702
    "frontendservice"  = 1387364332
    "loadgen"          = 1387365686
    "paymentservice"   = 1387367125
    "rec-service"      = 1387370438
    "shippingservice"  = 1387372189
    "shopping-service" = 1387374036
  }

  gha_dev_repos = ["infra"]  #repos where the dev branch is allowed to assume the OIDC role. 

  gha_subs = concat(
    [
      for name, id in local.gha_repos :
      "repo:${local.gh_owner}@${local.gh_owner_id}/${name}@${id}:ref:refs/heads/main"
    ],
    [
      for name in local.gha_dev_repos :
      "repo:${local.gh_owner}@${local.gh_owner_id}/${name}@${local.gha_repos[name]}:ref:refs/heads/dev"
    ]
  )
}

#OIDC FOR GITHUB ACTIONS
resource "aws_iam_openid_connect_provider" "gh_actions_oidc" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "gha_oidc_role" {
  name = "gha-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.gh_actions_oidc.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.gha_subs
        }
      }
    }]
  })
} 

#BACKEND INFRA
resource "aws_s3_bucket" "s3_terraform_state" {
  for_each = local.envs
  bucket = "terraform-state-bucket-${each.key}-${local.account_id}"
  tags = { Purpose = "tf State", Env = each.key }
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.s3_terraform_state
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role_policy" "tf_state" {
  name = "tf_state_policy"
  role = aws_iam_role.gha_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "StateBucket"
        Effect = "Allow"

        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]

        Resource = [
          for bucket in aws_s3_bucket.s3_terraform_state :
          bucket.arn
        ]
      },
      {
        Sid    = "StateObjects"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = flatten([
          for bucket in aws_s3_bucket.s3_terraform_state : [
            "${bucket.arn}/terraform.tfstate",
            "${bucket.arn}/terraform.tfstate.tflock"
          ]
        ])
      }
    ]
  })
}

resource "aws_iam_role_policy" "tf_ecr" {
  name = "tf_ecr_policy"
  role = aws_iam_role.gha_oidc_role.id

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
    },
    {
      Sid    = "EcrLogin"
      Effect = "Allow"
      Action = "ecr:GetAuthorizationToken"
      Resource = "*"
    },
    {
      Sid: "PushImages",
      Effect: "Allow",
      Action: [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchCheckLayerAvailability"
      ]
      Resource = "arn:aws:ecr:ap-south-2:${data.aws_caller_identity.current.account_id}:repository/*"
    }
    ]
  })
}