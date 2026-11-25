terraform {
  # Need 1.11+ for ephemeral variables
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  # bucket, key and region are passed at init time (see the makefile).
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
