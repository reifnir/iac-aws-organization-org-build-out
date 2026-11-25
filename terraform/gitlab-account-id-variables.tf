module "gitlab_account_id_variables" {
  source = "./modules/gitlab-account-id-variables"

  accounts    = data.aws_organizations_organization.this.accounts
  project_url = var.project_url
}

# Extracted from the root module into modules/gitlab-account-id-variables.
moved {
  from = gitlab_group_variable.aws_account_id
  to   = module.gitlab_account_id_variables.gitlab_group_variable.aws_account_id
}

# AWS_ACCOUNT_ID_ROOT was created by hand in both groups before this project managed
# it. Import blocks can only live in the root module.
import {
  to = module.gitlab_account_id_variables.gitlab_group_variable.aws_account_id["reifnir-public-projects:AWS_ACCOUNT_ID_ROOT"]
  id = "reifnir-public-projects:AWS_ACCOUNT_ID_ROOT:*"
}

import {
  to = module.gitlab_account_id_variables.gitlab_group_variable.aws_account_id["reifnir-private-projects:AWS_ACCOUNT_ID_ROOT"]
  id = "reifnir-private-projects:AWS_ACCOUNT_ID_ROOT:*"
}
