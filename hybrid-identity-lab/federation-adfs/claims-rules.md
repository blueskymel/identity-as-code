# ADFS Claims Rules Configuration

## Overview
Claims rules transform user attributes from Active Directory into claims that are included in SAML tokens.

## Common Claims Rules

### 1. Pass Through Claims Rule
```
c:[Type == "urn:microsoft:username"]
 => issue(claim = c);
```
Passes username as-is to the token.

### 2. Transform Claims Rule
```
c:[Type == "urn:microsoft:windowsaccountname"]
 => issue(Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn", Issuer = c.Issuer, OriginalIssuer = c.OriginalIssuer, Value = c.Value, ValueType = c.ValueType);
```
Transforms Windows account name to UPN claim.

### 3. Group to Role Mapping
```
c:[Type == "urn:microsoft:groups", Value =~ "(?i)^CN=Admins,.*"]
 => issue(Type = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role", Value = "Admin");
```
Maps Active Directory groups to application roles.

### 4. Custom Attribute Rule
```
c:[Type == "urn:microsoft:attributes", Value =~ "(?i)^department=finance$"]
 => issue(Type = "http://schemas.custom.com/claims/department", Value = "Finance");
```
Maps custom attributes to claims.

## Best Practices
- Use consistent claim naming conventions
- Validate rule syntax before deployment
- Test claims rules with test accounts
- Document all custom claims
- Review and update rules during upgrades
