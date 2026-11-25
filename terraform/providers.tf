# Runs as Reifnir-Root (the management account): StackSets with service-managed
# permissions can only be administered from there.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      "Application" = "aws-organization"
      "Environment" = "prod"
      "Managed By"  = "Terraform - DO NOT ALTER MANUALLY"
      "Project URL" = var.project_url
    }
  }
}

provider "gitlab" {
  token = var.gitlab_token
}
