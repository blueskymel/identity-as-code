# ADFS Failover Design and High Availability

## Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                    Azure AD                            │
│            (Relying Party Trust)                       │
└─────────────────┬──────────────────┬──────────────────┘
                  │                  │
        ┌─────────v──────┐   ┌──────v─────────┐
        │ ADFS Server 1  │   │ ADFS Server 2  │
        │ (Primary)      │   │ (Secondary)    │
        └────────┬───────┘   └───────┬────────┘
                 │                   │
        ┌────────┴───────────────────┘
        │
┌───────v────────────────────────┐
│  SQL Server (Shared Database)  │
│  (WID or SQL)                  │
└────────────────────────────────┘
        │
        ├─ Primary Domain Controller
        │
        └─ Replicated Domain Controllers
```

## HA Configuration

### Database Options

**Windows Internal Database (WID)**
- Built-in ADFS database
- Limited to 30 ADFS servers
- Automatic replication
- Suitable for small/medium deployments

**SQL Server**
- External database
- Unlimited ADFS servers
- Manual replication configuration
- Required for large/enterprise deployments

### Load Balancing

```powershell
# Configure Network Load Balancing (NLB)
# Or use hardware/cloud load balancer pointing to:
#   - fs.contoso.com (VIP)
#   - Points to ADFS servers
```

### Failover Scenarios

1. **Single ADFS Server Down**
   - Traffic automatically redirected to remaining servers
   - No user impact

2. **Database Failure**
   - ADFS servers use local cache temporarily
   - New tokens cannot be issued
   - Restore database to recover

3. **Partial Network Partition**
   - Requires quorum for token signing
   - May impact service availability

## Disaster Recovery

- Maintain replicated database
- Backup certificates regularly
- Document all configurations
- Test failover procedures quarterly
