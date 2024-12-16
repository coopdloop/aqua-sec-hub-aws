# IAM Permission Testing Guide

## Overview
This document outlines the IAM permissions structure and testing procedures for the GitHub Actions deployment pipeline.

## Permission Structure

### GitHub Actions Role
- Role Name Format: `{project-name}-github-actions-role-{environment}`
- Uses OIDC federation for secure authentication
- Implements a permission boundary for additional security

### Permission Sets

1. ECR Permissions
   - Token Generation: Allows ECR login
   - Image Push: Limited to specific repository
   - Image Pull: Read-only access to images

2. ECS Permissions
   - Service Updates: Limited to specific service
   - Cluster-scoped conditions

3. Security Hub Permissions
   - Findings Management: Import and retrieve findings
   - Read Access: Limited insight access

## Security Controls

1. Permission Boundary
   - Prevents privilege escalation
   - Denies IAM/Organization management
   - Restricts service scope

2. OIDC Authentication
   - No long-term credentials
   - Repository-specific access
   - Token-based authentication

3. Resource Tagging
   - Environment-based access control
   - Project tracking
   - Cost allocation

## Testing Procedures

### 1. ECR Access Testing
```bash
# Test ECR authentication
aws ecr get-login-password --region us-east-1

# Test image push
docker push $ECR_REPO:latest

# Test image pull
docker pull $ECR_REPO:latest
```

### 2. ECS Access Testing
```bash
# Test service update
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment

# Verify denied actions
aws ecs create-service # Should fail
```

### 3. Security Hub Testing
```bash
# Test findings import
aws securityhub batch-import-findings --findings file://findings.json

# Test findings retrieval
aws securityhub get-findings

# Test insight access
aws securityhub get-insights
```

### 4. Permission Boundary Testing
```bash
# Verify IAM restrictions
aws iam create-user --user-name test # Should fail

# Verify allowed actions
aws securityhub get-findings # Should succeed
```

## Best Practices

1. Least Privilege
   - Use specific resource ARNs
   - Implement condition statements
   - Separate policies by service

2. Security
   - Enable CloudTrail logging
   - Use resource tags for access control
   - Implement permission boundaries

3. Monitoring
   - Enable AWS Config
   - Use CloudWatch metrics
   - Monitor Security Hub findings

## Troubleshooting

1. Access Denied Errors
   - Check role trust relationship
   - Verify resource ARNs
   - Check condition statements

2. Permission Issues
   - Validate OIDC configuration
   - Check permission boundary
   - Verify resource tags

3. Security Hub Integration
   - Verify product subscription
   - Check finding format
   - Validate account/region

## Regular Maintenance

1. Periodic Reviews
   - Audit permissions quarterly
   - Update documentation
   - Review security findings

2. Updates
   - Keep policies current
   - Update permission boundaries
   - Maintain OIDC configuration
