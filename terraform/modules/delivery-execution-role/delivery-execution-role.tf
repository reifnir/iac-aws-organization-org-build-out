# ReifnirDeliveryExecution: an AdministratorAccess role in every account in the
# organization, assumable only by the GitLab pipeline role in Reifnir-Delivery and by
# Identity Center users signed in to Reifnir-Delivery with AWSAdministratorAccess.
# The role itself is defined in delivery-execution-role.yaml.
#
# - Reifnir-Root gets it from a plain CloudFormation stack, because StackSets never
#   deploy to the management account. The provider must be Reifnir-Root's.
# - Every other account gets it from a service-managed StackSet targeting the
#   organization root, with auto-deployment, so new accounts get it on arrival and
#   accounts that leave lose it.

locals {
  # The role GitLab pipelines assume in Reifnir-Delivery with their OIDC ID token.
  delivery_pipeline_role_name = "ReifnirGitLabPipeline"
  delivery_pipeline_role_arn  = "arn:aws:iam::${var.delivery_account_id}:role/${local.delivery_pipeline_role_name}"

  # The Identity Center permission set whose users in Reifnir-Delivery may also assume
  # the role, for hands-on work and break-fix outside a pipeline.
  delivery_admin_permission_set_name = "AWSAdministratorAccess"

  template = file("${path.module}/delivery-execution-role.yaml")
  template_parameters = {
    DeliveryAccountId              = var.delivery_account_id
    DeliveryPipelineRoleName       = local.delivery_pipeline_role_name
    DeliveryAdminPermissionSetName = local.delivery_admin_permission_set_name
  }
}

resource "aws_cloudformation_stack" "root" {
  #checkov:skip=CKV_AWS_124:Automation falls down immediately when this role isn't deployed, so a failed stack can't go unnoticed. No SNS notifications needed.
  name          = "ReifnirDeliveryExecution"
  template_body = local.template
  parameters    = local.template_parameters
  capabilities  = ["CAPABILITY_NAMED_IAM"]
}

resource "aws_cloudformation_stack_set" "member_accounts" {
  name             = "ReifnirDeliveryExecution"
  description      = "ReifnirDeliveryExecution role in every member account."
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = local.template
  parameters       = local.template_parameters

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

resource "aws_cloudformation_stack_set_instance" "organization_root" {
  stack_set_name            = aws_cloudformation_stack_set.member_accounts.name
  stack_set_instance_region = "us-east-1"

  deployment_targets {
    organizational_unit_ids = [var.organization_root_id]
  }
}
