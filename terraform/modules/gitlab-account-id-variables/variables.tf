variable "accounts" {
  description = "Accounts in the AWS organization (aws_organizations_organization's accounts). Only ACTIVE ones get a variable."
  type = list(object({
    id    = string
    name  = string
    state = string
  }))
  nullable = false
}

variable "project_url" {
  description = "URL of the GitLab project that manages these variables, recorded in each variable's description."
  type        = string
  nullable    = false
}
