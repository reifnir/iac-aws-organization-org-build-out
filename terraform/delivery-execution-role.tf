module "delivery_execution_role" {
  source = "./modules/delivery-execution-role"

  delivery_account_id = one([
    for account in data.aws_organizations_organization.this.accounts : account.id
    if account.name == "Reifnir-Delivery"
  ])
  organization_root_id = data.aws_organizations_organization.this.roots[0].id
}
