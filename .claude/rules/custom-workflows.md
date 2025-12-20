# Custom Workflows

This file documents project-specific workflows and processes that are unique to your project.

## Purpose

Use this file to define:
- Custom development workflows
- Release processes
- Deployment procedures
- Team-specific ceremonies
- Integration with external systems

## Template

### Development Workflow

<!-- Example:
1. Pick issue from backlog
2. Create feature branch from `develop`
3. Implement changes
4. Write/update tests
5. Create PR to `develop`
6. Address review comments
7. Merge after CI passes
-->

### Release Workflow

<!-- Example:
1. Create release branch from `develop`
2. Update version numbers
3. Run full test suite
4. Generate release notes
5. Create PR to `main`
6. Tag release after merge
7. Deploy to production
-->

### Hotfix Workflow

<!-- Example:
1. Create hotfix branch from `main`
2. Fix critical bug
3. Update tests
4. Create PR to `main` and `develop`
5. Fast-track review
6. Deploy immediately after merge
-->

### Feature Flag Management

<!-- Example:
- How to create a new feature flag
- When to use feature flags
- How to retire feature flags
- Feature flag naming conventions
-->

### Database Migration Workflow

<!-- Example:
1. Create migration script
2. Test on local database
3. Review migration with DBA
4. Test on staging environment
5. Schedule production deployment
6. Monitor after deployment
-->

### Deployment Process

<!-- Example:
- Staging deployment: Automatic on merge to `develop`
- Production deployment: Manual approval required
- Rollback procedure: Use deployment platform rollback feature
- Health checks: Monitor for 30 minutes after deployment
-->

### Code Freeze Procedures

<!-- Example:
- When: 2 days before major release
- What: Only critical bugfixes allowed
- Process: All changes require release manager approval
-->

### External Integration Points

<!-- Example:
- CI/CD: GitHub Actions, Jenkins
- Monitoring: Datadog, Sentry
- Cloud: AWS, GCP
- Issue tracking: JIRA, Linear
-->

### On-Call Procedures

<!-- Example:
- Rotation: Weekly rotation
- Escalation: Level 1 → Level 2 → Manager
- Response time: Critical issues within 15 minutes
- Incident documentation: Post-mortem required for all P0 incidents
-->

### Code Review SLA

<!-- Example:
- P0 (critical): 1 hour
- P1 (high): 4 hours
- P2 (normal): 24 hours
- P3 (low): 48 hours
-->

### Testing Environments

<!-- Example:
- Local: Individual developer machines
- Development: Shared dev environment
- Staging: Production-like environment
- Production: Live system
-->

### Access Control

<!-- Example:
- Repository access: Managed through GitHub teams
- Production access: Requires manager approval
- Secrets: Stored in HashiCorp Vault
- SSH keys: Rotated every 90 days
-->

## Custom Commands

<!-- Document any custom slash commands or shortcuts -->

### `/deploy-staging`
<!-- Example: Description and usage -->

### `/run-migration`
<!-- Example: Description and usage -->

---

**Note**: Update this file as workflows evolve. Keep it synchronized with team practices.
