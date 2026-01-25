# Terraform Infrastructure as Code (IaC) Pipeline

## Overview

The IaC CI/CD pipeline automates the provisioning, validation, and management of AWS infrastructure using Terraform. It includes comprehensive security scanning, compliance checks, and approval gates for safe infrastructure changes.

## Pipeline Architecture

```
Git Push → Checkout
                ↓
        Terraform Init
                ↓
        Terraform Validate
                ↓
        TFLint Scan (Code Quality)
                ↓
        tfsec Security Scan (Security)
                ↓
        Checkov Compliance Scan (Compliance)
                ↓
        Terraform Plan
                ↓
        Manual Approval (Apply or Destroy)
                ↓
        Terraform Apply / Destroy
                ↓
        Update kubeconfig (if Apply)
                ↓
        Cleanup & Report
```

## Pipeline Stages

### Stage 1: Checkout
Clones the Git repository to get the latest Terraform code.

**Output**: Source code ready for processing

### Stage 2: Terraform Init
Initializes the Terraform working directory and downloads required providers.

**Purpose**: Prepare for Terraform operations
**Tools**: Terraform CLI

### Stage 3: Terraform Validate
Validates the Terraform configuration syntax and structure.

**Checks**:
- Configuration syntax
- Module structure
- Variable definitions
- Output definitions

**Fails Pipeline If**: Invalid Terraform syntax detected

### Stage 4: TFLint Scan
Runs TFLint to check for Terraform best practices and coding standards.

**Checks**:
- Naming conventions
- Code style
- Unused variables
- Missing attributes

**Tools**: TFLint

### Stage 5: tfsec Security Scan
Scans Terraform code for security misconfigurations and compliance issues.

**Checks**:
- IAM security
- Encryption settings
- Public access exposure
- AWS security best practices

**Tools**: tfsec (Aqua Security)
**Continue on Error**: Yes (warnings don't block pipeline)

### Stage 6: Checkov Compliance Scan
Performs compliance scanning against multiple frameworks.

**Checks**:
- CIS AWS Foundations Benchmark
- PCI DSS
- HIPAA
- SOC 2
- Custom policies

**Tools**: Checkov
**Continue on Error**: Yes (warnings don't block pipeline)

### Stage 7: Terraform Plan
Generates an execution plan showing what changes Terraform will make.

**Output**: `tfplan` artifact containing the plan
**Shows**:
- Resources to be created
- Resources to be modified
- Resources to be destroyed

### Stage 8: Manual Approval
Requires human approval before applying infrastructure changes.

**For Apply**: User must approve to proceed with `terraform apply`
**For Destroy**: User must confirm destruction (additional safety)

**Timeout**: 24 hours

### Stage 9: Terraform Apply
Applies the planned infrastructure changes to AWS.

**Actions**:
- Creates/modifies/destroys AWS resources
- Updates state file
- Generates Terraform outputs

**Prerequisite**: Manual approval granted

### Stage 10: Terraform Destroy (Optional)
Destroys infrastructure when explicitly requested (dangerous operation).

**Safeguards**:
- Must enable `DESTROY_INFRASTRUCTURE` parameter
- Requires manual approval
- Warning messages displayed

### Stage 11: Update kubeconfig
Updates the local kubeconfig file to access the deployed EKS cluster.

**Purpose**: Enable kubectl commands after cluster creation

**Only Runs**: When applying (not destroying)

## Build Parameters

### ENVIRONMENT (Required)
**Type**: Choice  
**Options**: dev, qa, prod  
**Purpose**: Specifies which environment to deploy/destroy  
**Default**: dev

### DESTROY_INFRASTRUCTURE (Optional)
**Type**: Boolean  
**Default**: false  
**Purpose**: Enable infrastructure destruction mode  
**Warning**: ⚠️ Extremely dangerous - use with caution!

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `TF_IN_AUTOMATION` | true | Tells Terraform it's running in automation |
| `AWS_DEFAULT_REGION` | us-east-1 | AWS region for infrastructure |
| `AWS_ACCOUNT_ID` | credentials | AWS account ID |
| `AWS_ACCESS_KEY_ID` | credentials | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | credentials | AWS secret key |

## Required Credentials

These credentials must be configured in Jenkins:

1. **aws-account-id** - Secret text with AWS account ID
2. **aws-access-key-id** - Secret text with AWS access key
3. **aws-secret-access-key** - Secret text with AWS secret key

## Security Scanning Tools

### TFLint
**Purpose**: Terraform code linting and best practices  
**Installation**: Auto-installed from GitHub  
**Configuration**: `.tflint.hcl` in terraform directory

### tfsec
**Purpose**: Security scanning for Terraform  
**Installation**: Auto-installed from GitHub  
**Checks**: IAM, encryption, public access, AWS security best practices

### Checkov
**Purpose**: Infrastructure as Code compliance scanning  
**Installation**: Auto-installed via pip  
**Frameworks**: CIS, PCI DSS, HIPAA, SOC 2, custom policies

## Approval Process

### For Apply Operations
1. Pipeline runs all validation and security scans
2. Terraform plan generated and reviewed
3. Jenkins shows "Input required" status
4. Approver reviews plan and approves/rejects in Jenkins UI
5. If approved: Terraform apply executes
6. If rejected: Pipeline fails and no changes applied

### For Destroy Operations
1. User must set `DESTROY_INFRASTRUCTURE=true`
2. Pipeline generates destruction plan
3. Multiple confirmation prompts displayed
4. Approver must explicitly approve destruction
5. If approved: `terraform destroy` executes
6. All infrastructure in environment is destroyed

### Timeout
- 24 hours for approval decision
- If not approved within 24 hours, pipeline times out
- Timed-out builds are marked as failed

## Artifacts

### Generated During Pipeline
- **tfplan** - Terraform execution plan
  - Archived as build artifact
  - Can be downloaded from Jenkins
  - Used to verify changes before approval

### Generated After Apply
- **terraform-outputs.txt** - Terraform outputs
  - Cluster endpoint
  - ECR repository URLs
  - Security group IDs
  - Other infrastructure details

## Post-Build Actions

### Always (Success or Failure)
- Clean up temporary files
- Remove tfplan artifact from workspace

### Success (Apply)
- Print confirmation message
- Display environment and build number
- Update kubeconfig for EKS access

### Success (Destroy)
- Print destruction confirmation
- Notify of resource removal

### Failure
- Print failure message
- Log environment and build details
- Preserve logs for debugging

## Error Handling

### Validation Failures
- TFLint issues: Non-blocking warnings
- Syntax errors: Block pipeline
- Security issues: Non-blocking warnings

### Plan Failures
- Invalid configuration: Pipeline stops
- Resource conflicts: Pipeline stops
- IAM permission issues: Pipeline stops

### Apply/Destroy Failures
- AWS API errors: Pipeline fails
- Insufficient permissions: Pipeline fails
- Resource conflicts: Pipeline fails

## Usage Examples

### Deploy Development Infrastructure

```groovy
Build with Parameters:
- ENVIRONMENT: dev
- DESTROY_INFRASTRUCTURE: false
```

Result: Development environment provisioned on AWS

### Deploy Production Infrastructure

```groovy
Build with Parameters:
- ENVIRONMENT: prod
- DESTROY_INFRASTRUCTURE: false
```

Result: Production environment provisioned with manual approval

### Destroy QA Infrastructure

```groovy
Build with Parameters:
- ENVIRONMENT: qa
- DESTROY_INFRASTRUCTURE: true
```

Result: QA environment destroyed with manual confirmation

## Troubleshooting

### "Terraform Init Failed"
- Check AWS credentials
- Verify S3 backend bucket exists
- Check IAM permissions

### "Plan Shows Unexpected Changes"
- Review Terraform variable values
- Check for drift in AWS resources
- Verify Terraform state file

### "Security Scan Failures"
- Review tfsec report
- Adjust security scanning rules if needed
- Document exceptions if acceptable

### "Approval Timed Out"
- Approve within 24 hours
- Re-run pipeline if timed out
- Check Jenkins for pending approvals

### "AWS Permission Denied"
- Verify IAM credentials
- Check IAM policy permissions
- Ensure correct AWS account
- Verify credentials are not expired

## Best Practices

### Before Deploying
1. Review Terraform plan carefully
2. Check security scanning results
3. Verify environment is correct
4. Test changes in dev first

### During Deployment
1. Monitor Jenkins build progress
2. Check AWS console for resources
3. Verify resource creation in logs

### After Deployment
1. Update kubeconfig
2. Test cluster connectivity
3. Verify resources are accessible
4. Document any manual configurations

### Destroying Infrastructure
1. Ensure it's intentional
2. Backup any important data
3. Get team approval
4. Verify environment parameter
5. Monitor destruction process

## Integration with Application Pipeline

The IaC pipeline and Application Pipeline work together:

1. **IaC Pipeline**: Provisions AWS infrastructure (EKS, ECR, VPC)
2. **Application Pipeline**: Builds and deploys applications to provisioned infrastructure

**Workflow**:
```
IaC Pipeline (Infrastructure) ↓
Application Pipeline (Apps) ↓
GitOps (ArgoCD) ↓
Running Applications on EKS
```

## Monitoring & Maintenance

### Regular Tasks
- Review Terraform state files
- Monitor AWS resource costs
- Update Terraform provider versions
- Scan for security drift

### Metrics to Track
- Plan-to-apply time
- Approval turn-around time
- Security scan findings
- Failed deployments

## Multi-Environment Strategy

### Development
- Automatic approval (can be changed)
- Minimal security requirements
- Rapid iteration
- Cost optimization

### QA
- Manual approval required
- Standard security requirements
- Mirrors production
- Performance testing

### Production
- Manual approval required
- Strict security requirements
- No automatic changes
- Backup and disaster recovery

## Documentation

For Terraform code documentation, see:
- [terraform/README.md](../../terraform/README.md)
- [terraform/variables.tf](../../terraform/variables.tf)
- [terraform/outputs.tf](../../terraform/outputs.tf)
- [terraform/main.tf](../../terraform/main.tf)

For infrastructure details:
- [docs/IMPLEMENTATION_PLAN.md](../../docs/IMPLEMENTATION_PLAN.md)
- [README.md](../../README.md)

## Support

For infrastructure issues:
1. Check terraform logs in Jenkins
2. Review AWS CloudFormation events
3. Check security scanning reports
4. Consult AWS documentation
5. Review Terraform state file

---

**Infrastructure as Code Pipeline - Ready for Production**
