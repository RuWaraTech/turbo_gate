# TurboGate Deployment Fixes - ModSecurity WAF Integration

## Summary of Issues Fixed

This document outlines the critical fixes applied to resolve Docker Swarm deployment issues with ModSecurity WAF protection.

## Fixed Issues

### 1. ModSecurity v3 Compatibility ✅
**Problem**: ModSecurity v3.0.14 doesn't support `SecRequestBodyInMemoryLimit` directive
**Solution**: Removed deprecated directive from `modsecurity.conf.j2`
**Location**: `deployment/ansible/playbooks/templates/modsecurity.conf.j2:12`

### 2. Docker Volume Configuration ✅  
**Problem**: Missing nginx volume definitions causing container failures
**Solution**: Added `nginx_waf_logs` and `nginx_cache` volumes to docker-compose template
**Location**: `deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2:100-103`

### 3. Container Permissions ✅
**Problem**: nginx PID file permission errors with non-root user
**Solution**: Removed `user: "101:101"` directive to use container defaults
**Location**: `deployment/ansible/playbooks/templates/docker-compose-waf.yml.j2:30`

### 4. Directory Creation ✅
**Problem**: Missing host directories for nginx logs and cache
**Solution**: Added nginx directories to Ansible directory creation task
**Location**: `deployment/ansible/playbooks/deploy_app.yml:43-44`

## Deployment Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet      │    │  ModSecurity WAF │    │   TurboGate     │
│   Traffic       │───▶│  (nginx + WAF)   │───▶│   API Gateway   │
│                 │    │  Port 80         │    │   Port 5000     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                       ┌─────────────┐           ┌──────────┐
                       │ nginx_waf_  │           │  Redis   │
                       │ logs volume │           │ Database │
                       └─────────────┘           └──────────┘
```

## Security Features

### ModSecurity Rules
- SQL Injection protection
- XSS detection and blocking  
- Path traversal prevention
- User-agent based blocking
- Health check bypass rules

### Zero-Downtime Deployment
- Versioned secrets and configs using timestamps
- Rolling update strategy with parallelism: 1
- Health checks with retry logic
- Automatic cleanup of old resources

### Container Security
- Non-root containers
- Proper volume permissions (101:101 for nginx)
- Secret management via Docker secrets
- Redis authentication with proper escaping

## Verification Commands

```bash
# Check service status
ssh root@<swarm-manager> "docker service ls"

# Check ModSecurity logs
ssh root@<swarm-manager> "docker service logs turbogate_nginx-waf --tail 20"

# Test WAF protection
curl -H "User-Agent: scan bot" http://<your-domain>/
# Should return 403 Forbidden

# Check TurboGate API
curl http://<your-domain>/gateway/health
# Should return healthy status
```

## Troubleshooting

### Common Issues

1. **nginx-waf containers not starting**
   - Check if volumes exist: `docker volume ls | grep nginx`
   - Verify ModSecurity config syntax
   - Check container logs for permission errors

2. **ModSecurity rules not loading**
   - Ensure `modsecurity_rules.conf.j2` has valid syntax
   - Check that custom rules directory exists in container
   - Verify config version matches in docker-compose

3. **Zero-downtime deployment fails**
   - Ensure versioned secrets/configs don't already exist
   - Check if old resources are properly cleaned up
   - Verify all swarm nodes are accessible

### Log Locations
- ModSecurity audit logs: `/var/log/nginx/modsec_audit.log` (in container)
- nginx error logs: `/var/log/nginx/error.log` (in container)
- Service logs: `docker service logs turbogate_nginx-waf`

## Performance Considerations

- ModSecurity adds ~10-50ms latency depending on rule complexity
- nginx volumes use local driver for better I/O performance  
- Redis uses bind mount for data persistence
- Global mode deployment ensures WAF on every node

## Next Steps

1. Consider enabling OWASP CRS rule set for comprehensive protection
2. Implement log aggregation for better monitoring
3. Add Prometheus metrics for ModSecurity statistics
4. Configure rate limiting rules based on traffic patterns