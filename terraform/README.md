# Terraform Foundation

This directory contains Terraform configuration used by the repository's hybrid identity-as-code model.

## Intent

- Manage declarative identity and platform controls with Terraform whenever provider support is appropriate.
- Keep Graph PowerShell for operational identity tasks that are not a good Terraform fit.

## Local Validation

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
```

## Next Modules

- Named locations
- Enterprise applications
- App Proxy connectors
- Log Analytics and Sentinel integration
