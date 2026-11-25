module "delivery_execution_role" {
  source = "./modules/delivery-execution-role"

  delivery_account_id = one([
    for account in data.aws_organizations_organization.this.accounts : account.id
    if account.name == "Reifnir-Delivery"
  ])
  organization_root_id = data.aws_organizations_organization.this.roots[0].id
}

# Extracted from the root module into modules/delivery-execution-role.
moved {
  from = aws_cloudformation_stack.delivery_execution_root
  to   = module.delivery_execution_role.aws_cloudformation_stack.root
}

moved {
  from = aws_cloudformation_stack_set.delivery_execution
  to   = module.delivery_execution_role.aws_cloudformation_stack_set.member_accounts
}

moved {
  from = aws_cloudformation_stack_set_instance.delivery_execution_org_root
  to   = module.delivery_execution_role.aws_cloudformation_stack_set_instance.organization_root
}
