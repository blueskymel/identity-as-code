# Pipelines

This directory contains the Azure DevOps pipeline YAML and placeholder files you can fill in later for GitHub Actions secrets and Azure DevOps variable groups.

## What Is In Scope

The repository currently has three GitHub Actions workflows and one Azure DevOps pipeline:

| File | Purpose |
|------|---------|
| [`.github/workflows/validate.yml`](../.github/workflows/validate.yml) | Validates JSON and Terraform on PR, push, or manual trigger |
| [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) | Deploys identity configuration through dev, staging, and prod |
| [`.github/workflows/rollback.yml`](../.github/workflows/rollback.yml) | Rolls back identity configuration manually |
| [`azure-devops.yml`](azure-devops.yml) | Azure DevOps equivalent of the deploy pipeline |

## How Values Flow

### GitHub Actions

- Authentication is handled by `azure/login@v2`
- The workflow reads these GitHub secrets:
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `AZURE_CLIENT_ID_DEV`
  - `AZURE_CLIENT_ID_STAGING`
  - `AZURE_CLIENT_ID_PROD`
- Workflow inputs control deployment behavior:
  - `environment`
  - `resource`
  - `whatif`
- The workflow converts those inputs into PowerShell script arguments such as `-Environment dev` and `-WhatIf`

Use [`github-actions.secrets.example.env`](github-actions.secrets.example.env) as a placeholder checklist. It is documentation only; GitHub Actions does not load this file automatically.

### Azure DevOps

- Authentication is handled by Azure DevOps service connections referenced by name in `azure-devops.yml`
- The current YAML expects these service connection names:
  - `identity-as-code-dev`
  - `identity-as-code-staging`
  - `identity-as-code-prod`
- The current YAML also references these variable group names:
  - `identity-as-code-dev`
  - `identity-as-code-staging`
  - `identity-as-code-prod`
- Pipeline parameters control deployment behavior:
  - `environment`
  - `resource`
  - `whatif`
- The pipeline converts `whatif` into `$(WHATIF_FLAG)` and passes `-Environment <env>` into the deploy scripts

Use [`azure-devops.variable-group.example.env`](azure-devops.variable-group.example.env) as a placeholder template for the variable groups. The example file is not loaded automatically; copy its keys into each Azure DevOps variable group in the UI or via your preferred automation.

## Required GitHub Actions Setup

### Repository Secrets

Create these repository secrets in GitHub:

| Secret | Required | Purpose |
|--------|----------|---------|
| `AZURE_TENANT_ID` | Yes | Tenant used by deploy and rollback workflows |
| `AZURE_SUBSCRIPTION_ID` | Yes | Subscription passed to `azure/login@v2` |
| `AZURE_CLIENT_ID_DEV` | Yes | Client ID used for dev deployments |
| `AZURE_CLIENT_ID_STAGING` | Yes | Client ID used for staging deployments |
| `AZURE_CLIENT_ID_PROD` | Yes | Client ID used for production deployments |

### GitHub Environments

Create these GitHub environments:

- `dev`
- `staging`
- `prod`

Recommended configuration:

- leave `dev` open for normal execution
- add required reviewers or approval rules to `staging`
- add required reviewers or approval rules to `prod`

### Federated Credentials

For each client ID above, configure workload identity federation in Entra ID so GitHub Actions can exchange the GitHub OIDC token for access. The repository does not store client secrets.

## Required Azure DevOps Setup

### Service Connections

Create Azure service connections with these exact names unless you also update `azure-devops.yml`:

| Name | Required | Used By |
|------|----------|---------|
| `identity-as-code-dev` | Yes | Dev deployment stage |
| `identity-as-code-staging` | Yes | Staging deployment stage |
| `identity-as-code-prod` | Yes | Production deployment stage |

### Azure DevOps Environments

Create these Azure DevOps environments:

- `dev`
- `staging`
- `prod`

Recommended configuration:

- use approval checks for `staging`
- use approval checks for `prod`

### Variable Groups

Create these variable groups:

- `identity-as-code-dev`
- `identity-as-code-staging`
- `identity-as-code-prod`

The current pipeline YAML references these groups by name. Even though the current deployment steps authenticate through service connections, the groups still need to exist because the pipeline loads them at runtime.

Recommended keys for each variable group:

- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID_DEV`
- `AZURE_CLIENT_ID_STAGING`
- `AZURE_CLIENT_ID_PROD`

If you want each group to contain only environment-specific values, you can keep the same keys and set the values appropriately for that environment.

## Script Entry Points Used By Pipelines

These are the actual deployment scripts used by the pipelines:

| Script | Used By | Notes |
|--------|---------|-------|
| [`../scripts/deploy-ca-policies.ps1`](../scripts/deploy-ca-policies.ps1) | GitHub Actions and Azure DevOps | Uses `-Environment`, `-WhatIf`, and optional `-StateOverride` |
| [`../scripts/deploy-dynamic-groups.ps1`](../scripts/deploy-dynamic-groups.ps1) | GitHub Actions and Azure DevOps | Uses `-Environment` and `-WhatIf` |
| [`../scripts/deploy-administrative-units.ps1`](../scripts/deploy-administrative-units.ps1) | GitHub Actions and Azure DevOps | Uses `-Environment` and `-WhatIf` |
| [`../scripts/deploy-role-assignments.ps1`](../scripts/deploy-role-assignments.ps1) | GitHub Actions and Azure DevOps | Uses `-Environment` and `-WhatIf` |

These deploy scripts currently call `Connect-MgGraph -Identity`, so they are designed for managed or federated identity execution contexts rather than interactive workstation prompts.

## Loader Scripts Versus Deploy Scripts

The top-level scaffolding folders also contain `Invoke-*Template.ps1` scripts:

- `ConditionalAccess/scripts/Invoke-ConditionalAccessTemplate.ps1`
- `AppRegistrations/scripts/Invoke-AppRegistrationTemplate.ps1`
- `EnterpriseApps/scripts/Invoke-EnterpriseAppTemplate.ps1`
- `PIM/scripts/Invoke-PimTemplate.ps1`
- `AccessReviews/scripts/Invoke-AccessReviewTemplate.ps1`
- `LifecycleWorkflows/scripts/Invoke-LifecycleWorkflowTemplate.ps1`

These scripts:

- take only a template path
- load the JSON template
- print the parsed template content

They do not:

- authenticate to Entra ID
- read pipeline secrets
- read Azure DevOps variable groups
- perform token substitution
- deploy resources

## How Templates Handle Variables

Template files such as `*.template.json` and the deployable JSON definitions under `conditional-access/`, `dynamic-groups/`, `administrative-units/`, and `role-assignments/` are static JSON.

Current behavior:

- no `{{token}}` replacement
- no `.env` file loading
- no automatic environment-variable expansion inside JSON
- no per-environment template rendering step

Instead, environment-specific behavior is controlled outside the JSON:

- pipelines choose which environment is being deployed
- scripts receive `-Environment`
- scripts receive `-WhatIf`
- Conditional Access deployments apply `-StateOverride enabledForReportingButNotEnforced` for dev/report-only scenarios

## Placeholder Files You Can Fill In Later

The following files were added as fill-in-later templates:

| File | Purpose |
|------|---------|
| [`github-actions.secrets.example.env`](github-actions.secrets.example.env) | Copy values from here into GitHub repository secrets |
| [`azure-devops.variable-group.example.env`](azure-devops.variable-group.example.env) | Copy values from here into each Azure DevOps variable group |

These files are safe to commit because they contain placeholders only.
