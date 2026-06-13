# Hybrid Identity Lab

This folder contains comprehensive implementation guidance for three modern hybrid identity sign-in models with Microsoft Entra ID (Azure AD).

## Overview

Hybrid identity allows organizations to maintain on-premises Active Directory while leveraging cloud capabilities of Microsoft Entra ID. Choose the pattern that best matches your organization's security requirements, complexity tolerance, and on-premises infrastructure.

## Sign-In Models

### 1. Password Hash Synchronization (PHS)

**Best for**: Cloud-first organizations, simple infrastructure, cost optimization

**Overview**: Synchronizes a hashed copy of passwords from on-premises AD to the cloud. Users authenticate against cloud copies without requiring on-premises connectivity.

**Key Characteristics**:
- ✅ Simplest to implement and maintain
- ✅ No agent infrastructure required
- ✅ Works offline (cloud-only authentication)
- ❌ Password hash stored in cloud (though still hashed)
- ❌ Requires premium licensing for full features

**Contents**: [`password-hash-sync/`](password-hash-sync/)
- `architecture.md` - Detailed architecture and data flow
- `setup-entra-connect.md` - Azure AD Connect installation and configuration
- `enable-password-hash-sync.ps1` - Automation script to enable PHS
- `sync-health-check.ps1` - Monitoring and health verification
- `login-flow-diagram.md` - Visual authentication flow

---

### 2. Pass-Through Authentication (PTA)

**Best for**: Enterprise security-first, real-time validation, password never in cloud

**Overview**: Validates user credentials in real-time against on-premises Active Directory. Authentication requests are forwarded to PTA agents that validate directly against AD.

**Key Characteristics**:
- ✅ Password never leaves on-premises
- ✅ Real-time credential validation
- ✅ No password synchronization
- ⚠️ Requires agent infrastructure (minimum 3 agents for HA)
- ⚠️ More complex than PHS
- ⚠️ Dependent on on-premises availability

**Contents**: [`pass-through-authentication/`](pass-through-authentication/)
- `pta-agent-install.md` - Agent deployment and configuration
- `authentication-flow.md` - PTA authentication flow diagram
- `agent-health-check.ps1` - Agent status monitoring
- `troubleshooting-pta.md` - Common issues and solutions
- `high-availability-design.md` - Multi-agent HA architecture

---

### 3. Federation with ADFS

**Best for**: Complex legacy environments, advanced claims transformation, compliance requirements

**Overview**: Uses Active Directory Federation Services (ADFS) to issue SAML tokens. Credentials are validated on-premises and federation assertions are passed to the cloud.

**Key Characteristics**:
- ✅ Most control over authentication process
- ✅ Advanced claims transformation capabilities
- ✅ Supports legacy compliance requirements
- ✅ Can enforce additional on-premises policies
- ❌ Highest complexity
- ❌ Significant infrastructure requirements
- ❌ Requires certificate management
- ❌ Most operational overhead

**Contents**: [`federation-adfs/`](federation-adfs/)
- `adfs-setup.md` - ADFS installation and farm configuration
- `saml-token-flow.md` - SAML token generation and validation flow
- `claims-rules.md` - Claims rules configuration and examples
- `certificate-rotation.md` - Certificate lifecycle management
- `adfs-failover-design.md` - High availability and DR design
- `login-flow-testing.md` - Testing scenarios and procedures

---

## Comparison Matrix

| Aspect | PHS | PTA | ADFS |
|--------|-----|-----|------|
| **Implementation Complexity** | Low | Medium | High |
| **Operational Overhead** | Low | Medium | High |
| **Infrastructure Required** | Minimal | Moderate | Significant |
| **Password Security** | Cloud hash | On-prem only | On-prem only |
| **Real-time Validation** | No | Yes | Yes |
| **On-prem Dependency** | Sync only | Critical | Critical |
| **Claims Transformation** | Basic | No | Advanced |
| **MFA Integration** | Yes | Yes | Yes |
| **Conditional Access** | Yes | Yes | Yes |
| **Cost** | Low | Medium | High |
| **Deployment Timeline** | Days | Weeks | Weeks/Months |

---

## Choosing Your Pattern

### Choose PHS if:
- You want simplicity and low operational overhead
- You're comfortable with password hashes in the cloud
- You have good cloud connectivity
- You want to minimize on-premises infrastructure
- You're building a modern, cloud-first identity system

### Choose PTA if:
- You need real-time password validation
- You want passwords to remain on-premises only
- You have reliable on-premises infrastructure
- You can support multiple agent deployments
- You want a middle ground between PHS and ADFS complexity

### Choose ADFS if:
- You have legacy compliance requirements
- You need advanced claims transformation
- You're in a complex enterprise environment
- You need to enforce on-premises policies
- You can support full ADFS infrastructure and operational costs

---

## Implementation Roadmap

### Phase 1: Preparation
1. Audit current environment
2. Review security requirements
3. Plan infrastructure
4. Pilot with test accounts

### Phase 2: Deployment
1. Configure Azure AD Connect
2. Deploy agents (if PTA) or ADFS (if federation)
3. Configure sync/authentication rules
4. Test with pilot users

### Phase 3: Validation
1. Test login flows
2. Validate health monitoring
3. Test failover scenarios
4. Performance validation

### Phase 4: Production
1. Gradual user migration
2. Production monitoring
3. Operational runbooks
4. Disaster recovery validation

---

## Security Considerations

### All Models
- Enable MFA via Conditional Access
- Monitor authentication failures
- Regular security assessments
- Implement break-glass accounts

### PHS
- Ensure Azure AD Connect server is hardened
- Monitor sync status regularly
- Keep sync rules updated

### PTA
- Deploy agents in HA configuration
- Monitor agent health
- Validate network connectivity
- Maintain certificate validity

### ADFS
- Implement ADFS farm redundancy
- Monitor certificate expiration
- Regular ADFS configuration backups
- Test failover procedures quarterly

---

## Monitoring and Alerting

Each pattern includes health check scripts:

```powershell
# PHS Health Check
./password-hash-sync/sync-health-check.ps1

# PTA Health Check
./pass-through-authentication/agent-health-check.ps1
```

Implement alerts for:
- Sync failures (PHS)
- Agent connectivity (PTA)
- Certificate expiration (all)
- Authentication failures (all)
- Performance degradation (all)

---

## Migration Between Models

You can migrate between models:
- **PHS → PTA**: Deploy agents, test, update Azure AD
- **PHS/PTA → ADFS**: Deploy ADFS, establish federation, retire old method
- **ADFS → PHS/PTA**: Modernize cloud-first architecture

Plan migrations carefully with pilot phases and rollback procedures.

---

## Support and References

- [Microsoft Hybrid Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/)
- [Azure AD Connect Documentation](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/whatis-azure-ad-connect)
- [Pass-Through Authentication](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-pta)
- [ADFS Deployment Guide](https://docs.microsoft.com/en-us/windows-server/identity/ad-fs/deployment/windows-server-2016-federation-deployment-guide)

---

## Quick Links

| Topic | Path |
|-------|------|
| Architecture | `*/architecture.md` or `*/adfs-setup.md` |
| Setup & Config | `*/setup-*.md` or `*/pta-agent-install.md` |
| Health Monitoring | `*/*-health-check.ps1` |
| Troubleshooting | `*/troubleshooting-*.md` |
| High Availability | `*/high-availability-design.md` or `*/adfs-failover-design.md` |
| Testing | `*/login-flow-*.md` |
