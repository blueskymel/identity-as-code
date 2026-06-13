# SAML Token Flow in ADFS

## Overview
When using ADFS federation, authentication uses SAML 2.0 tokens for secure communication between identity providers and service providers.

## Token Flow Process

```
┌──────────────────┐
│  User/Browser    │
└────────┬─────────┘
         │ 1. Request cloud resource
         │
┌────────v──────────────────────┐
│  Azure AD                      │
│  (Relying Party Trust)         │
│  Recognize federated domain    │
└────────┬──────────────────────┘
         │ 2. Redirect to ADFS
         │
┌────────v─────────────────────────────┐
│  ADFS Service                         │
│  (Identity Provider - IdP)            │
│  Display login page                   │
└────────┬─────────────────────────────┘
         │ 3. Enter credentials
         │
┌────────v─────────────────────────────┐
│  ADFS Authentication                  │
│  • Authenticate against local AD      │
│  • Generate SAML token                │
│  • Sign token with certificate        │
└────────┬─────────────────────────────┘
         │ 4. Return SAML token
         │
┌────────v──────────────────────────────┐
│  Azure AD                              │
│  • Validate SAML signature             │
│  • Verify certificate                  │
│  • Extract claims                      │
│  • Issue Azure AD tokens               │
└────────┬──────────────────────────────┘
         │ 5. Grant cloud access
         │
┌────────v──────────────────────────────┐
│  Application Access Granted            │
└───────────────────────────────────────┘
```

## SAML Token Components

- **Assertion**: Authentication confirmation with identity claims
- **Signature**: Ensures token integrity and authenticity
- **Certificate**: Public key for signature validation
- **Subject**: User identity
- **Audience**: Intended recipient (Azure AD)
- **Conditions**: Token validity constraints
