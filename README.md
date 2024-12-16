# Secure Container Pipeline with AWS Security Hub Integration

## Overview
This project implements a secure container deployment pipeline with automated security scanning and reporting. It uses AWS Fargate for container orchestration and integrates with AWS Security Hub for centralized security findings management.

### Key Features
- Containerized application deployment on AWS Fargate
- Automated vulnerability scanning with Aqua Trivy
- Infrastructure as Code (IaC) security scanning
- SBOM (Software Bill of Materials) generation
- Real-time security findings reporting to AWS Security Hub
- GitHub Actions CI/CD pipeline with OIDC authentication

## Architecture

### Infrastructure Components
1. **Container Registry (ECR)**
   - Secure container image storage
   - Automated vulnerability scanning on push
   - Immutable tags support

2. **Container Orchestration (ECS/Fargate)**
   - Serverless container execution
   - Automated scaling
   - Secure networking configuration

3. **Security Monitoring**
   - AWS Security Hub integration
   - Automated vulnerability reporting
   - Infrastructure misconfigurations detection
   - Secrets scanning
   - SBOM generation and analysis

4. **Networking**
   - VPC with public subnet
   - Security group controls
   - Container-level network isolation

### Security Features

1. **IAM Security**
   - OIDC authentication for GitHub Actions
   - Least privilege permissions
   - Permission boundaries
   - Resource-level access control
   - Environment-based access restrictions

2. **Container Security**
   - Image vulnerability scanning
   - Runtime security controls
   - Immutable infrastructure patterns
   - Security group restrictions

3. **Compliance**
   - AWS Foundational Security Best Practices
   - Automated security findings
   - Real-time security monitoring
   - Compliance reporting via Security Hub

## Pipeline Workflow

1. **Build Phase**
   ```mermaid
   graph LR
       A[Source Code] --> B[Build Container]
       B --> C[Scan Image]
       C --> D[Push to ECR]
   ```

2. **Security Scanning**
   - Container vulnerability scanning
   - Infrastructure as Code analysis
   - Secrets detection
   - SBOM generation
   - Security Hub integration

3. **Deployment**
   - Automated ECS service updates
   - Blue-green deployment support
   - Rollback capabilities

## Security Controls

### Access Control
- OIDC-based authentication
- Role-based access control
- Resource-level permissions
- Environment segregation

### Monitoring and Logging
- Security Hub integration
- Vulnerability tracking
- IaC security monitoring
- Compliance reporting

### Network Security
- VPC isolation
- Security group controls
- Public subnet configuration
- Container network policies

## Getting Started

### Prerequisites
1. AWS Account with appropriate permissions
2. GitHub repository
3. Terraform installed locally
4. AWS CLI configured

### Deployment Steps
1. Clone the repository
2. Configure variables in `terraform.tfvars`:
   ```hcl
   github_org           = "your-org"
   github_repo          = "your-repo"
   project_name         = "your-project"
   environment          = "dev"
   allowed_account_ids  = ["your-aws-account-id"]
   ```

3. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. Configure GitHub Actions:
   - Add AWS Role ARN to GitHub Secrets
   - Configure OIDC provider
   - Update workflow with repository details

### Monitoring and Maintenance

1. **Security Hub Dashboard**
   - Monitor security findings
   - Track vulnerability remediation
   - View compliance status

2. **Regular Maintenance**
   - Update container images
   - Review security findings
   - Apply infrastructure updates
   - Monitor resource usage

3. **Compliance Checks**
   - Review Security Hub standards
   - Monitor compliance scores
   - Track remediation progress

## Contributing
Please see CONTRIBUTING.md for guidelines on how to contribute to this project.

## Security
For security concerns or vulnerability reports, please see SECURITY.md for reporting procedures.

## License
This project is licensed under the MIT License - see LICENSE.md for details.
