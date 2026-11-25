output "root_role_arn" {
  description = "ARN of ReifnirDeliveryExecution in Reifnir-Root."
  value       = aws_cloudformation_stack.root.outputs["RoleArn"]
}

output "delivery_pipeline_role_arn" {
  description = "The GitLab pipeline role allowed to assume ReifnirDeliveryExecution (Identity Center AWSAdministratorAccess users in Reifnir-Delivery may too)."
  value       = local.delivery_pipeline_role_arn
}
