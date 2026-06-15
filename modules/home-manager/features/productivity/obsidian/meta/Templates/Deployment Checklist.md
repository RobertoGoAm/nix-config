---
status: Template
lastUpdated: 2024-04-03
type: template
tags: [template, deployment]
---

# {{Project Name}} Deployment Checklist

## Pre-Deployment
### Code Review
- [ ] All PRs reviewed and merged
- [ ] No failing tests
- [ ] Code coverage meets target
- [ ] Linting passes
- [ ] Type checking passes

### Documentation
- [ ] API documentation updated
- [ ] README updated
- [ ] Changelog updated
- [ ] Deployment guide reviewed
- [ ] Rollback plan documented

### Security
- [ ] Security scan completed
- [ ] Dependencies updated
- [ ] Secrets rotated
- [ ] Access permissions reviewed
- [ ] Compliance checks passed

### Performance
- [ ] Load testing completed
- [ ] Performance metrics reviewed
- [ ] Database indexes optimized
- [ ] Caching strategy verified
- [ ] Resource limits checked

## Deployment
### Infrastructure
- [ ] Backup completed
- [ ] Scaling rules verified
- [ ] Monitoring enabled
- [ ] Alerts configured
- [ ] Logging verified

### Database
- [ ] Migrations tested
- [ ] Backup restored
- [ ] Indexes created
- [ ] Permissions verified
- [ ] Data integrity checked

### Application
- [ ] Environment variables set
- [ ] Configuration verified
- [ ] Assets uploaded
- [ ] Cache cleared
- [ ] Services restarted

### Integration
- [ ] API endpoints verified
- [ ] Webhooks tested
- [ ] Third-party services checked
- [ ] SSL certificates valid
- [ ] DNS configured

## Post-Deployment
### Verification
- [ ] Health checks passing
- [ ] Metrics normal
- [ ] Logs clean
- [ ] Performance normal
- [ ] Security verified

### Monitoring
- [ ] Alerts active
- [ ] Logs flowing
- [ ] Metrics collecting
- [ ] Error tracking active
- [ ] Performance monitoring active

### Communication
- [ ] Team notified
- [ ] Stakeholders updated
- [ ] Support team briefed
- [ ] Documentation published
- [ ] Status page updated

## Rollback Plan
### Triggers
- Critical errors
- Performance degradation
- Security issues
- Data corruption
- Service disruption

### Steps
1. Identify issue
2. Notify stakeholders
3. Execute rollback
4. Verify systems
5. Document incident

## References
- [[Deployment Guide]]
- [[Rollback Procedure]]
- [[Monitoring Setup]]
- [[Alert Configuration]]
- [[Support Procedures]] 