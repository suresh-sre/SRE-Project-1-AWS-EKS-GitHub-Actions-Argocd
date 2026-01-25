# DevOps CI/CD Pipeline with AWS EKS and GitHub Actions

A production-ready CI/CD pipeline for deploying applications to AWS EKS with comprehensive security scanning, policy enforcement, and GitOps-based deployment using ArgoCD and GitHub Actions.

##  Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Pipeline Stages](#pipeline-stages)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Infrastructure Modules](#infrastructure-modules)
- [Pipeline Configuration](#pipeline-configuration)
- [Deployment Workflow](#deployment-workflow)
- [Security & Compliance](#security--compliance)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [Contributing](#contributing)

##  Overview

This project implements a complete DevOps CI/CD pipeline using **GitHub Actions** that addresses common challenges in AWS, Kubernetes (EKS), Terraform, Docker, and container deployments. The pipeline automates the entire software delivery lifecycle from code commit to production deployment.

### Key Features

-  **Infrastructure as Code**: Complete Terraform modules for AWS EKS, VPC, and ECR
-  **GitHub Actions CI/CD**: Automated workflows for build, test, and deploy
-  **Security Scanning**: Snyk SAST and container image vulnerability scanning
-  **Policy Enforcement**: Kyverno policies for Kubernetes security and compliance
-  **GitOps Deployment**: ArgoCD for declarative, automated deployments
-  **Multi-Environment**: Separate configurations for dev, qa, and prod
-  **Production-Ready**: Health checks, resource limits, autoscaling, and monitoring

##  Architecture

``

                  GitHub Actions CI/CD Pipeline                  

 Step 1: Initialize  Environment Validation                    
 Step 2: Platform Check  EKS Cluster Health                   
 Step 3: Validate  Dockerfile, K8s, Kyverno, Snyk SAST       
 Step 4: Build  Maven Artifact Generation                     
 Step 5: Package  Docker Image + Helm Chart  ECR            
 Step 6: Container Scan  Snyk Vulnerability Scan              
 Step 7: Promote  Update Config Repo  ArgoCD Deployment     
 Step 8: Approval Gates  Manual Approval (QA/Prod)           
 Step 9: Verify  ArgoCD Sync Status                          

                              

                      AWS Infrastructure                          

  VPC  EKS Cluster  Worker Nodes                               
  ECR  Container Images + Helm Charts                           
  ArgoCD  Config Repo  Automated Deployments                  

``

##  Pipeline Stages

### Step 1: Initialize

Validates environment branch matching and sets up build metadata.

**Checks:**
- Branch matches target environment (dev/qa/prod)
- Git metadata collection (commit, branch, timestamp)

### Step 2: Platform Check

Validates that the target EKS cluster is operational before deployment.

**Checks:**
- EKS cluster status is ACTIVE
- Worker nodes exist and are in Ready state
- Critical system pods are running (kube-system namespace)

**Script:** [scripts/check-eks-cluster.sh](scripts/check-eks-cluster.sh)

### Step 3: Validate (Parallel)

- **Validate Dockerfile** - Hadolint linting
- **Validate Kubernetes** - kubeconform manifest validation
- **Validate Kyverno Policies** - Security policy testing
- **SAST Security Scan** - Snyk source code vulnerability scanning

**Script:** [scripts/validate-k8s-manifests.sh](scripts/validate-k8s-manifests.sh)

### Step 4: Build

Compiles Java application with Maven and generates JAR/WAR artifacts.

### Step 5: Package (Parallel)

**Package Docker Image**
- Build Docker image from [Dockerfile](Dockerfile)
- Tag with commit SHA and environment
- Push to AWS ECR

**Package Helm Chart**
- Package Helm chart with version metadata
- Push to AWS ECR

### Step 6: Container Security Scan

Snyk scans built Docker image for security vulnerabilities and CVEs.

### Step 7: Promote to ArgoCD

Updates GitOps config repository for ArgoCD deployment.

**Script:** [scripts/update-config-repo.sh](scripts/update-config-repo.sh)

### Step 8: Approval Gates

- **QA**: Manual approval required before deployment
- **Production**: Manual approval required before deployment

### Step 9: Verify ArgoCD Deployment

Checks ArgoCD application sync status after deployment.

##  Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **AWS CLI** >= 2.0
- **kubectl** >= 1.28
- **Helm** >= 3.0
- **Docker** >= 24.0
- **Maven** >= 3.8
- **Git** >= 2.0

### Required Accounts & Credentials

- AWS account with EKS, ECR, VPC permissions
- GitHub repository with GitHub Actions enabled
- Snyk account and API token
- ArgoCD installation on target clusters

### GitHub Actions Secrets Configuration

Set these in **Settings  Secrets and Variables  Actions**:

``
AWS_ACCESS_KEY_ID          # AWS IAM access key
AWS_SECRET_ACCESS_KEY      # AWS IAM secret key
AWS_ACCOUNT_ID             # 12-digit AWS account ID
SNYK_TOKEN                 # Snyk API token
ARGOCD_SERVER              # ArgoCD server URL
ARGOCD_TOKEN               # ArgoCD authentication token
GIT_TOKEN                  # GitHub personal access token
``

##  Quick Start

### 1. Clone the Repository

``ash
git clone https://github.com/suresh-subramanian2013/SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd.git
cd SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd
``

### 2. Configure GitHub Secrets

1. Go to **Settings  Secrets and Variables  Actions**
2. Add the required secrets (see Prerequisites section)

### 3. Deploy Infrastructure

``ash
cd terraform

# Initialize Terraform
terraform init

# Create S3 bucket for state (one-time setup)
aws s3 mb s3://terraform-state-cicd-pipeline --region us-east-1

# Plan infrastructure
terraform plan -var="environment=dev"

# Apply infrastructure
terraform apply -var="environment=dev"

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name cicd-pipeline-dev
``

### 4. Install ArgoCD

``ash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
``

### 5. Install Kyverno

``ash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.10.0/install.yaml

# Apply custom policies
kubectl apply -f kyverno-policies/
``

### 6. Deploy ArgoCD Applications

``ash
# Apply ArgoCD application definitions
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-qa.yaml
kubectl apply -f argocd/application-prod.yaml
``

### 7. Trigger First Build

Push code to dev, qa, or prod branch. GitHub Actions automatically triggers the pipeline:

``ash
git checkout dev
git push origin dev
``

##  Infrastructure Modules

### Terraform Modules

#### VPC Module

Creates a production-ready VPC with:
- 3 public subnets across availability zones
- 3 private subnets for EKS worker nodes
- NAT gateways for outbound internet access
- EKS-specific tags for load balancer provisioning

#### EKS Module

Provisions an AWS EKS cluster with:
- Managed node groups with autoscaling
- OIDC provider for IRSA support
- Essential add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver
- CloudWatch logging for control plane

#### ECR Module

Creates ECR repositories with:
- Scan-on-push enabled for security
- Lifecycle policies (retain last 30 images)
- Encryption at rest (AES256)

### Customization

Edit [terraform/variables.tf](terraform/variables.tf):

``hcl
variable "environment" {
  default = "dev"
}

variable "eks_cluster_version" {
  default = "1.28"
}

variable "node_groups" {
  default = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
    }
  }
}
``

##  Pipeline Configuration

### GitHub Actions Workflow Files

Located in .github/workflows/:

- **build.yml** - Build, test, and compile application
- **security-scan.yml** - Run Snyk SAST and container scans
- **deploy.yml** - Deploy to EKS via ArgoCD

### Environment Variables

Set these in **Settings  Variables**:

| Variable | Description |
|----------|-------------|
| AWS_REGION | AWS region (e.g., us-east-1) |
| EKS_CLUSTER_NAME | EKS cluster name |
| ECR_REGISTRY | ECR registry URL |
| ARGOCD_SYNC_TIMEOUT | ArgoCD sync timeout in seconds |

##  Deployment Workflow

### Development Environment

- **Trigger:** Push to dev branch
- **Build:** Automatic via GitHub Actions
- **Deployment:** Automatic to EKS dev cluster
- **ArgoCD Sync:** Automatic

### QA Environment

- **Trigger:** Push to qa branch
- **Build:** Automatic via GitHub Actions
- **Deployment:** Manual approval required
- **Tests:** Available for QA team
- **ArgoCD Sync:** Automatic after approval

### Production Environment

- **Trigger:** Push to prod branch
- **Build:** Automatic via GitHub Actions
- **Deployment:** Manual approval required (senior review)
- **ArgoCD Sync:** Manual (for additional safety)
- **Rollback:** Via ArgoCD UI

##  Security & Compliance

### Kyverno Policies

1. **Restrict Privileged Containers** - Prevents privileged pods
2. **Require Resource Limits** - Enforces CPU/memory limits
3. **Disallow Host Namespaces** - Prevents host PID/IPC/network access

### Snyk Security Scanning

- **SAST Stage:** Source code vulnerability scanning
- **Container Scan Stage:** Docker image CVE scanning
- **Threshold:** High severity findings block pipeline
- **Monitor:** Snyk continuously monitors deployed artifacts

### Docker Security

The [Dockerfile](Dockerfile) implements:
- Non-root user execution
- Multi-stage builds
- Minimal base image (JRE slim)
- Health checks
- No unnecessary privileges

##  Troubleshooting

### Common Issues

#### EKS Cluster Not Ready

``ash
aws eks describe-cluster --name cicd-pipeline-dev --region us-east-1
``

#### Worker Nodes Not Ready

``ash
kubectl get nodes
kubectl describe node <node-name>
``

#### Dockerfile Validation Failed

Update Dockerfile to pin package versions:

``dockerfile
RUN apt-get update && apt-get install -y curl=7.68.0-1 && rm -rf /var/lib/apt/lists/*
``

#### Snyk Scan Failures

``ash
mvn versions:display-dependency-updates
``

#### ArgoCD Not Syncing

``ash
argocd app sync cicd-demo-app-dev
``

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

##  Project Structure

``
sre-project-1/
 .github/workflows/                 # GitHub Actions workflows
    build.yml                      # Build and test workflow
    security-scan.yml              # Security scanning
    deploy.yml                     # Deployment workflow
 terraform/                         # Infrastructure as Code
    main.tf
    variables.tf
    outputs.tf
    backend.tf
    modules/
        vpc/
        eks/
        ecr/
 helm-chart/                        # Kubernetes Helm chart
    Chart.yaml
    values.yaml
    templates/
 kyverno-policies/                  # Security policies
 argocd/                            # ArgoCD applications
 scripts/                           # Helper scripts
 src/                               # Sample Java app
 Dockerfile                         # Application container image
 pom.xml                            # Maven config
 README.md                          # This file
``

##  Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (\git checkout -b feature/amazing-feature\)
3. Commit changes (\git commit -m 'Add feature'\)
4. Push branch (\git push origin feature/amazing-feature\)
5. Open a Pull Request

##  License

This project is licensed under the MIT License.

##  Support

For questions or issues:
- Create an issue in the repository
- Contact: devops@example.com

---

**Built with  by the DevOps Team**

**GitHub Actions CI/CD Edition**
