1. Creating infrastructure from scratch:

2. Bootstrap Terraform by creating the backend S3 bucket, the OIDC provider for GHA, and the role for the OIDC and policy for the S3 bucket using the bootstrap configuration file and AWS SSO login (temporary access).
3. Then used that S3 bucket as backend and set up a Terraform workflow using a CI/CD pipeline on GH Actions
4. Using an OIDC identity provider of GitHub to authenticate Terraform to GitHub, thereby avoiding hardcoded secrets
5. The CI/CD pipeline for Terraform has two branches: main and dev. Changes to the configuration are submitted to dev, which runs terraform plan using GitHub Actions and submits the plan as a PR request.
