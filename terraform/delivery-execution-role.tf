# ReifnirDeliveryExecution: an AdministratorAccess role in every account in the
# organization, assumable only by the GitLab pipeline role in Reifnir-Delivery.
#
# - Reifnir-Root gets it from a plain CloudFormation stack, because StackSets never
#   deploy to the management account.
# - Every other account gets it from a service-managed StackSet targeting the
#   organization root, with auto-deployment, so new accounts get it on arrival and
#   accounts that leave lose it.

data "aws_organizations_organization" "this" {}

locals {
  delivery_account_id = one([
    for account in data.aws_organizations_organization.this.accounts : account.id
    if account.name == "Reifnir-Delivery"
  ])

  # The role GitLab pipelines assume in Reifnir-Delivery with their OIDC ID token.
  delivery_pipeline_role_arn = "arn:aws:iam::${local.delivery_account_id}:role/ReifnirGitLabPipeline"

  # CloudFormation has no first-class Terraform representation for a template,
  # so the template body is built here; the trust policy inside it is not.
  delivery_execution_template = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "ReifnirDeliveryExecution role, assumable only by the GitLab pipeline role in Reifnir-Delivery."
    Resources = {
      Role = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName                 = "ReifnirDeliveryExecution"
          Description              = "Deploy role for GitLab pipelines in Reifnir-Delivery. Managed by Terraform via CloudFormation."
          MaxSessionDuration       = 3600
          ManagedPolicyArns        = ["arn:aws:iam::aws:policy/AdministratorAccess"]
          AssumeRolePolicyDocument = jsondecode(data.aws_iam_policy_document.delivery_execution_trust.json)
        }
      }
    }
    Outputs = {
      RoleArn = {
        Value = { "Fn::GetAtt" = ["Role", "Arn"] }
      }
    }
  })
}

# Trusts the Delivery account, then narrows to the one pipeline role with
# aws:PrincipalArn. Naming the role directly as the principal would fail while the
# role doesn't exist yet, and would silently stop matching if it were recreated.
data "aws_iam_policy_document" "delivery_execution_trust" {
  statement {
    sid     = "DeliveryGitLabPipelineOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.delivery_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalArn"
      values   = [local.delivery_pipeline_role_arn]
    }
  }
}

resource "aws_cloudformation_stack" "delivery_execution_root" {
  name          = "ReifnirDeliveryExecution"
  template_body = local.delivery_execution_template
  capabilities  = ["CAPABILITY_NAMED_IAM"]
}

resource "aws_cloudformation_stack_set" "delivery_execution" {
  name             = "ReifnirDeliveryExecution"
  description      = "ReifnirDeliveryExecution role in every member account."
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = local.delivery_execution_template

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  managed_execution {
    active = true
  }

  lifecycle {
    # AWS returns an administration role ARN for service-managed StackSets even
    # though none is set, which otherwise shows as a diff on every plan.
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "delivery_execution_org_root" {
  stack_set_name            = aws_cloudformation_stack_set.delivery_execution.name
  stack_set_instance_region = "us-east-1"

  deployment_targets {
    organizational_unit_ids = [data.aws_organizations_organization.this.roots[0].id]
  }
}
