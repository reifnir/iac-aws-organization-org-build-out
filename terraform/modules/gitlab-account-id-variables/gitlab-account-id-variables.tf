# GitLab group variables AWS_ACCOUNT_ID_<LAST WORD OF ACCOUNT NAME> (e.g.
# Reifnir-Log-Archive -> AWS_ACCOUNT_ID_ARCHIVE) for every ACTIVE account, in both
# top-level groups, so pipelines never hard-code account numbers.
#
# Two accounts whose names end in the same word would produce the same key; the map
# below then fails with a duplicate-key error instead of silently picking one.

locals {
  aws_account_id_variables = {
    for account in var.accounts :
    "AWS_ACCOUNT_ID_${upper(reverse(split("-", account.name))[0])}" => {
      account_id   = account.id
      account_name = account.name
    }
    if account.state == "ACTIVE"
  }

  gitlab_groups = ["reifnir-public-projects", "reifnir-private-projects"]

  gitlab_variables = {
    for pair in setproduct(local.gitlab_groups, keys(local.aws_account_id_variables)) :
    "${pair[0]}:${pair[1]}" => {
      group   = pair[0]
      key     = pair[1]
      account = local.aws_account_id_variables[pair[1]]
    }
  }
}

resource "gitlab_group_variable" "aws_account_id" {
  for_each = local.gitlab_variables

  group             = each.value.group
  key               = each.value.key
  value             = each.value.account.account_id
  description       = "AWS account ID of ${each.value.account.account_name}. Managed by Terraform in ${var.project_url}"
  environment_scope = "*"
  # Merge request plans need these too, and an account ID isn't a secret.
  protected = false
  masked    = false
  raw       = true
}
