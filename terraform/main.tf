locals {
  hybrid_model_enabled = true
}

output "hybrid_model_enabled" {
  description = "Indicates Terraform foundation is enabled for hybrid identity-as-code."
  value       = local.hybrid_model_enabled
}
