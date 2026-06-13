# Password Hash Synchronization Architecture

## Overview
Password Hash Sync (PHS) synchronizes a hashed copy of user passwords from on-premises Active Directory to Azure AD. This is the simplest and least complex authentication method.

## Components
- **Azure AD Connect**: Synchronizes identities and password hashes
- **On-Premises AD**: Source of truth for passwords
- **Azure AD**: Cloud directory with hashed password copies

## Authentication Flow
1. User enters credentials at Azure AD login page
2. Credential is hashed and compared against cloud copy
3. If match, user is authenticated to cloud service

## Advantages
- Low complexity and cost
- Works offline (cloud authentication only)
- No additional on-premises infrastructure needed
- Simple to implement and maintain

## Disadvantages
- Password hash stored in cloud (though still hashed)
- Requires Azure AD Premium for full features
- Less suitable for high-security environments
