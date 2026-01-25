# SRE Project 1: DevSecOps - AWS EKS CI/CD Pipeline

Enterprise-grade CI/CD pipeline combining Infrastructure as Code (IaC), GitOps, and DevSecOps practices for AWS EKS deployments.

##  Quick Links

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Infrastructure Setup](#infrastructure-setup)
- [Application CI/CD](#application-cicd)
- [Security & Compliance](#security--compliance)

## Project Overview

This SRE project demonstrates a complete production-ready platform combining:

- **Infrastructure as Code (IaC)**: Terraform modules for AWS infrastructure (VPC, EKS, ECR)
- **CI/CD Pipeline**: GitHub Actions workflows for build, test, security scanning, and deployment
- **GitOps Deployment**: ArgoCD for declarative, continuous deployment
- **Kubernetes Security**: Kyverno policies and RBAC enforcement
- **DevSecOps**: Snyk scanning, container image scanning, policy validation

## Architecture

### High-Level Flow

`
Code Commit  GitHub Actions  Build & Test  Security Scan  ECR Push 
     
   ArgoCD  Kubernetes Deployment  Kyverno Validation  Monitoring
`

### Components

| Component | Purpose | Technology |
|-----------|---------|-----------|
| **IaC** | AWS infrastructure provisioning | Terraform, Helm |
| **CI Pipeline** | Build & test automation | GitHub Actions, Maven, Docker |
| **Security** | Vulnerability scanning & compliance | Snyk, Kyverno, kubeconform |
| **CD Pipeline** | Automated deployment | ArgoCD, kubectl, Helm |
| **Container Registry** | Image storage & management | AWS ECR |
| **Orchestration** | Container management | AWS EKS, Kubernetes |

## Getting Started

### Prerequisites

- **AWS Account**: With permissions for EC2, VPC, EKS, ECR, IAM
- **Tools**: Terraform, AWS CLI, kubectl, Docker, Maven, Helm
- **GitHub**: Repository with Actions enabled
- **Accounts**: Snyk, ArgoCD (self-hosted or cloud)

### Step 1: Setup AWS Infrastructure

`ash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
`

**What this does:**
- Creates VPC with public/private subnets across 3 AZs
- Provisions EKS cluster with managed node groups
- Sets up ECR repositories for container images
- Configures IAM roles and security groups

### Step 2: Install ArgoCD

`ash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI (port-forward)
kubectl port-forward -n argocd svc/argocd-server 8080:443
`

### Step 3: Deploy Kyverno Policies

`ash
kubectl apply -f kyverno-policies/

# Verify installation
kubectl get clusterpolicy
`

### Step 4: Configure GitHub Secrets

Add these to **GitHub  Settings  Secrets and Variables  Actions**:

`
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_ACCOUNT_ID
SNYK_TOKEN
ARGOCD_SERVER
ARGOCD_TOKEN
GIT_TOKEN
`

### Step 5: Deploy Application

`ash
# Create ArgoCD applications
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-qa.yaml
kubectl apply -f argocd/application-prod.yaml

# Push code to trigger pipeline
git push origin dev
`

## Project Structure

`
sre-project-1/
 terraform/                    # Infrastructure as Code
    main.tf                   # Core AWS resources
    variables.tf              # Input variables
    outputs.tf                # Output values
    backend.tf                # S3 backend config
    modules/
        vpc/                  # Network infrastructure
        eks/                  # Kubernetes cluster
        ecr/                  # Container registry

 helm-chart/                   # Kubernetes deployment
    Chart.yaml
    values.yaml
    values-dev.yaml
    values-prod.yaml
    templates/
        deployment.yaml
        service.yaml
        ingress.yaml
        hpa.yaml

 kyverno-policies/             # Security policies
    restrict-privileged-pods.yaml
    require-resource-limits.yaml
    disallow-host-namespaces.yaml

 argocd/                       # GitOps configuration
    application-dev.yaml
    application-qa.yaml
    application-prod.yaml

 scripts/                      # Helper scripts
    check-eks-cluster.sh      # Cluster health check
    validate-k8s-manifests.sh # Manifest validation
    update-config-repo.sh     # ArgoCD sync trigger

 src/                          # Sample application
    main/java/com/example/
        App.java

 Dockerfile                    # Container image definition
 pom.xml                       # Maven configuration
 README.md                     # This file
 WALKTHROUGH.md                # Detailed setup guide
`

## Infrastructure Setup

### Terraform Modules

#### VPC Module (	erraform/modules/vpc/)

Creates networking foundation:
- 3 public subnets (1 per AZ)
- 3 private subnets for worker nodes
- NAT gateways for outbound traffic
- Internet gateway and route tables
- EKS-specific tags for AWS load balancer controller

**Customize:** Edit 	erraform/variables.tf

`hcl
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
`

#### EKS Module (	erraform/modules/eks/)

Provisions Kubernetes cluster:
- EKS control plane with logging enabled
- Managed node groups with auto-scaling
- IAM roles for node and pod access
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Essential add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI

**Customize:** Edit 	erraform/variables.tf

`hcl
variable "eks_version" {
  default = "1.28"
}

variable "node_groups" {
  default = {
    general = {
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      instance_types = ["t3.medium"]
    }
  }
}
`

#### ECR Module (	erraform/modules/ecr/)

Sets up container registry:
- ECR repositories for application images
- Scan-on-push enabled for security
- Lifecycle policies (retain last 30 images)
- Encryption at rest

### Deploy Infrastructure

`ash
# Initialize backend
aws s3 mb s3://terraform-state-- --region us-east-1

# Plan
terraform plan -var="environment=dev" -out=tfplan

# Apply
terraform apply tfplan

# Output kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cicd-pipeline-dev

# Verify cluster
kubectl cluster-info
kubectl get nodes
`

## Application CI/CD

### GitHub Actions Workflows

Located in .github/workflows/:

#### Build Workflow

Triggered on: Push to any branch

**Steps:**
1. Checkout code
2. Setup Java/Maven environment
3. Run unit tests
4. Build Maven artifact (JAR/WAR)
5. SAST security scan (Snyk)
6. Build Docker image
7. Push to ECR
8. Scan container image (Snyk)

#### Deploy Workflow

Triggered on: Push to dev, qa, or prod branch

**Steps:**
1. Validate kubeconfig and cluster health
2. Validate Kubernetes manifests (kubeconform)
3. Validate Kyverno policies
4. Package Helm chart
5. Update ArgoCD config repository
6. Manual approval gate (QA/Prod)
7. Trigger ArgoCD sync
8. Verify deployment health

### Pipeline Environments

| Environment | Branch | Auto Deploy | Approval | Sync |
|------------|--------|------------|----------|------|
| **Development** | dev |  Yes |  No | Automatic |
| **QA** | qa |  Yes |  Required | Automatic |
| **Production** | prod |  Yes |  Required | Manual |

### Deployment Example

`ash
# 1. Make changes
git checkout dev
git add .
git commit -m "Add feature"

# 2. Push (triggers GitHub Actions)
git push origin dev

# 3. Monitor pipeline
# - View Actions tab in GitHub
# - Check logs in CloudWatch

# 4. Verify deployment
kubectl -n default get pods
kubectl -n default get svc
`

## Security & Compliance

### Kyverno Policies

Enforce security at admission time:

1. **Restrict Privileged Containers**
   - Prevents privileged: true
   - Blocks llowPrivilegeEscalation
   - Enforces non-root users

2. **Require Resource Limits**
   - CPU requests/limits
   - Memory requests/limits
   - Prevents resource starvation

3. **Disallow Host Namespaces**
   - Blocks host PID/IPC/network access
   - Prevents container escape

Apply policies:
`ash
kubectl apply -f kyverno-policies/
`

### Container Scanning

**Build Time:**
- Snyk scans source code (SAST)
- Snyk scans Docker images (SCA)
- Fails pipeline on high-severity findings

**Runtime:**
- ECR scans on push
- Continuous monitoring via Snyk

**Commands:**
`ash
# Local SAST scan
snyk test --all-projects

# Local container scan
snyk container test myimage:latest

# Monitor artifacts
snyk monitor
`

### Best Practices Implemented

| Category | Implementation |
|----------|----------------|
| **Container** | Non-root user, minimal base image, multi-stage builds |
| **Kubernetes** | Resource limits, health checks, pod disruption budgets |
| **Network** | Private subnets for workers, NACLs, security groups |
| **IAM** | IRSA, least-privilege roles, audit logging |
| **Monitoring** | CloudWatch logs, EKS control plane logging |

## Troubleshooting

### EKS Cluster Issues

`ash
# Check cluster status
aws eks describe-cluster --name cicd-pipeline-dev --region us-east-1

# View cluster events
kubectl get events --all-namespaces

# Check node status
kubectl get nodes -o wide
kubectl describe node <node-name>

# View logs
aws logs tail /aws/eks/cicd-pipeline-dev/cluster --follow
`

### ArgoCD Deployment Issues

`ash
# Check application sync status
argocd app get cicd-demo-app-dev

# Manual sync
argocd app sync cicd-demo-app-dev

# View application logs
kubectl logs -n argocd deployment/argocd-application-controller
`

### Kyverno Policy Violations

`ash
# Check policy violations
kubectl get clusterpolicy
kubectl describe clusterpolicy restrict-privileged

# View violation events
kubectl get events --field-selector reason=PolicyViolation

# Check policy logs
kubectl logs -n kyverno deployment/kyverno
`

### GitHub Actions Pipeline Failures

1. **Check workflow logs**: GitHub  Actions  Select workflow  View logs
2. **Validate credentials**: Verify all secrets are set in GitHub Settings
3. **Check Snyk token**: Ensure Snyk account has API access
4. **Verify AWS permissions**: Check IAM policy for required services
5. **Test locally**: Run same commands in terminal to debug

## Contributing

1. Create feature branch: git checkout -b feature/my-feature
2. Make changes and commit: git commit -m "Add feature"
3. Push branch: git push origin feature/my-feature
4. Open Pull Request for review
5. After merge, pipeline automatically deploys to dev

## Documentation

- [WALKTHROUGH.md](WALKTHROUGH.md) - Step-by-step setup guide
- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) - Detailed implementation
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and fixes

## License

MIT License

## Support

For issues or questions:
- Open GitHub issue
- Check documentation files
- Review CloudWatch logs
- Contact: devops@example.com

---

**Last Updated:** January 2026  
**Maintained by:** DevOps Team
