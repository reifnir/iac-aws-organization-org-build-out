output "root_role_arn" {
  description = "ARN of ReifnirDeliveryExecution in Reifnir-Root."
  value       = aws_cloudformation_stack.root.outputs["RoleArn"]
}

output "delivery_pipeline_role_arn" {
  description = "The only principal allowed to assume ReifnirDeliveryExecution."
  value       = local.delivery_pipeline_role_arn
}
