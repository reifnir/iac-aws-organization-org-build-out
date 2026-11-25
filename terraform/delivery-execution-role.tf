# ReifnirDeliveryExecution: an AdministratorAccess role in every account in the
# organization, assumable only by the GitLab pipeline role in Reifnir-Delivery.
# The role itself is defined in delivery-execution-role.yaml.
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
  delivery_pipeline_role_name = "ReifnirGitLabPipeline"
  delivery_pipeline_role_arn  = "arn:aws:iam::${local.delivery_account_id}:role/${local.delivery_pipeline_role_name}"

  delivery_execution_template = file("${path.module}/delivery-execution-role.yaml")
  delivery_execution_parameters = {
    DeliveryAccountId        = local.delivery_account_id
    DeliveryPipelineRoleName = local.delivery_pipeline_role_name
  }
}

resource "aws_cloudformation_stack" "delivery_execution_root" {
  #checkov:skip=CKV_AWS_124:Automation falls down immediately when this role isn't deployed, so a failed stack can't go unnoticed. No SNS notifications needed.
  name          = "ReifnirDeliveryExecution"
  template_body = local.delivery_execution_template
  parameters    = local.delivery_execution_parameters
  capabilities  = ["CAPABILITY_NAMED_IAM"]
}

resource "aws_cloudformation_stack_set" "delivery_execution" {
  name             = "ReifnirDeliveryExecution"
  description      = "ReifnirDeliveryExecution role in every member account."
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = local.delivery_execution_template
  parameters       = local.delivery_execution_parameters

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
