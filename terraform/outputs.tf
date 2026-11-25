output "root_delivery_execution_role_arn" {
  description = "ARN of ReifnirDeliveryExecution in Reifnir-Root."
  value       = module.delivery_execution_role.root_role_arn
}

output "delivery_pipeline_role_arn" {
  description = "The only principal allowed to assume ReifnirDeliveryExecution."
  value       = module.delivery_execution_role.delivery_pipeline_role_arn
}
