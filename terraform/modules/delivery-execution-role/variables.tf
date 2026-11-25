variable "delivery_account_id" {
  description = "Account ID of Reifnir-Delivery, whose GitLab pipeline role and AWSAdministratorAccess Identity Center users are the only principals trusted by ReifnirDeliveryExecution."
  type        = string
  nullable    = false
}

variable "organization_root_id" {
  description = "ID of the organization root (r-...). The StackSet targets it, so every member account gets the role."
  type        = string
  nullable    = false
}
