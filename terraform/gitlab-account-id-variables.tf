module "gitlab_account_id_variables" {
  source = "./modules/gitlab-account-id-variables"

  accounts    = data.aws_organizations_organization.this.accounts
  project_url = var.project_url
}
