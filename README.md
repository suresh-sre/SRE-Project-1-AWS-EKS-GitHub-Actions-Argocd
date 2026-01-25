# DevOps CI/CD Pipeline with AWS EKS and Jenkins

A production-ready CI/CD pipeline for deploying applications to AWS EKS with comprehensive security scanning, policy enforcement, and GitOps-based deployment using ArgoCD.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Pipeline Stages](#pipeline-stages)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Jenkins Setup](#jenkins-setup)
- [Infrastructure Setup](#infrastructure-setup)
- [Pipeline Configuration](#pipeline-configuration)
- [Deployment Workflow](#deployment-workflow)
- [Security & Compliance](#security--compliance)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## 🎯 Overview

This project implements a complete DevOps CI/CD pipeline using **Jenkins** that addresses common challenges in AWS, Kubernetes (EKS), Terraform, Docker, and container deployments. The pipeline automates the entire software delivery lifecycle from code commit to production deployment.

### Key Features

- ✅ **Infrastructure as Code**: Complete Terraform modules for AWS EKS, VPC, and ECR
- ✅ **Jenkins CI/CD Pipeline**: Declarative pipeline with security scanning and approvals
- ✅ **Security Scanning**: Snyk SAST and container image vulnerability scanning
- ✅ **Policy Enforcement**: Kyverno policies for Kubernetes security and compliance
- ✅ **GitOps Deployment**: ArgoCD for declarative, automated deployments
- ✅ **Multi-Environment**: Separate configurations for dev, qa, and prod
- ✅ **Production-Ready**: Health checks, resource limits, autoscaling, and monitoring

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Jenkins CI/CD Pipeline                      │
├─────────────────────────────────────────────────────────────────┤
│ Stage 1: Initialize → Environment Validation                    │
│ Stage 2: Platform Check → EKS Cluster Health                   │
│ Stage 3: Validate → Dockerfile, K8s, Kyverno, Snyk SAST       │
│ Stage 4: Build → Maven Artifact Generation                     │
│ Stage 5: Package → Docker Image + Helm Chart → ECR            │
│ Stage 6: Container Scan → Snyk Vulnerability Scan              │
│ Stage 7: Promote → Update Config Repo → ArgoCD Deployment     │
│ Stage 8: Approval Gates → Manual Approval (QA/Prod)           │
│ Stage 9: Verify → ArgoCD Sync Status                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Infrastructure                          │
├─────────────────────────────────────────────────────────────────┤
│  VPC → EKS Cluster → Worker Nodes                               │
│  ECR → Container Images + Helm Charts                           │
│  ArgoCD → Config Repo → Automated Deployments                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Pipeline Stages

### Stage 1: Initialize

Validates environment branch matching and sets up build metadata.

**Checks:**
- Branch matches target environment (dev/qa/prod)
- Git metadata collection (commit, branch, timestamp)

### Stage 2: Platform Check

Validates that the target EKS cluster is operational before deployment.

**Checks:**
- EKS cluster status is ACTIVE
- Worker nodes exist and are in Ready state
- Critical system pods are running (kube-system namespace)

**Script:** [scripts/check-eks-cluster.sh](scripts/check-eks-cluster.sh)

### Stage 3: Validate (Parallel)

**Validate Dockerfile** - Hadolint linting  
**Validate Kubernetes** - kubeconform manifest validation  
**Validate Kyverno Policies** - Security policy testing  
**SAST Security Scan** - Snyk source code vulnerability scanning  

**Script:** [scripts/validate-k8s-manifests.sh](scripts/validate-k8s-manifests.sh)

### Stage 4: Build

Compiles Java application with Maven and generates JAR/WAR artifacts.

### Stage 5: Package (Parallel)

**Package Docker Image**
- Build Docker image from [Dockerfile](Dockerfile)
- Tag with commit SHA and environment
- Push to AWS ECR

**Package Helm Chart**
- Package Helm chart with version metadata
- Push to AWS ECR

### Stage 6: Container Security Scan

Snyk scans built Docker image for security vulnerabilities and CVEs.

### Stage 7: Promote to ArgoCD

Updates GitOps config repository for ArgoCD deployment.

**Script:** [scripts/update-config-repo.sh](scripts/update-config-repo.sh)

### Stage 8: Approval Gates

- **QA**: Manual approval required before deployment
- **Production**: Manual approval required before deployment

### Stage 9: Verify ArgoCD Deployment

Checks ArgoCD application sync status after deployment.

## 📦 Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **AWS CLI** >= 2.0
- **kubectl** >= 1.28
- **Helm** >= 3.0
- **Docker** >= 24.0
- **Maven** >= 3.8
- **Git** >= 2.0
- **Jenkins** >= 2.361 (LTS)

### Required Accounts & Credentials

- AWS account with EKS, ECR, VPC permissions
- Git repository (GitHub, GitLab, Gitea, etc.)
- Snyk account and API token
- ArgoCD installation on target clusters

### Jenkins Credentials Configuration

Set these in **Manage Jenkins → Manage Credentials**:

```
aws-access-key-id           # AWS IAM access key
aws-secret-access-key       # AWS IAM secret key
aws-account-id              # 12-digit AWS account ID
git-repository-url          # Git repository URL
git-credentials             # Git username/token
snyk-api-token             # Snyk API token
argocd-server              # ArgoCD server URL
argocd-token               # ArgoCD authentication token
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/sre-project-2.git
cd sre-project-2
```

### 2. Deploy Jenkins

#### Option A: Docker Compose

```bash
cd jenkins

# Create .env file with credentials
cat > .env << EOF
AWS_ACCOUNT_ID=123456789012
AWS_ACCESS_KEY_ID=YOUR_AWS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET
SNYK_TOKEN=YOUR_SNYK_TOKEN
ARGOCD_SERVER=https://argocd.example.com
ARGOCD_TOKEN=YOUR_ARGOCD_TOKEN
GIT_USERNAME=your-username
GIT_PASSWORD=your-token
DB_PASSWORD=secure-password
SMTP_HOST=mail.example.com
SMTP_USERNAME=smtp-user
SMTP_PASSWORD=smtp-password
EOF

# Start Jenkins
docker-compose up -d
```

#### Option B: Kubernetes Installation

```bash
# Create namespace
kubectl create namespace jenkins

# Add Jenkins Helm repository
helm repo add jenkinsci https://charts.jenkins.io
helm repo update

# Install Jenkins
helm install jenkins jenkinsci/jenkins -f jenkins/helm-values.yaml -n jenkins
```

#### Option C: Traditional Installation

```bash
# For Ubuntu/Debian
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo apt-get update
sudo apt-get install jenkins
```

### 3. Configure Jenkins

1. Access Jenkins at `http://localhost:8080`
2. Retrieve initial admin password:
   ```bash
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Complete setup wizard
4. Install recommended plugins
5. Add credentials (see Jenkins Credentials Configuration above)

For detailed setup instructions, see [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md)

## 🏗️ Jenkins Setup

### Create Pipeline Job

1. Click "New Item"
2. Enter job name: `cicd-pipeline`
3. Select "Pipeline"
4. Click "OK"

### Configure Pipeline

1. **General Settings**
   - Build history: Keep last 30 builds
   - Build timeout: 1 hour

2. **Pipeline Configuration**
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/your-org/sre-project-2.git`
   - Branch: `*/dev` (or create separate jobs for qa/prod)
   - Script Path: `Jenkinsfile`

3. **Build Triggers**
   - GitHub hook trigger for GITScm polling
   - Poll SCM: `H H(2-3) * * *` (daily)

4. **Parameters**
   - Choice: ENVIRONMENT (dev, qa, prod)
   - Boolean: SKIP_TESTS
   - Boolean: SKIP_SECURITY_SCAN

### Webhook Configuration

For automatic builds on code push:

1. In GitHub repository → Settings → Webhooks
2. Add webhook:
   - Payload URL: `http://jenkins-url:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Push events
   - Active: ✓

For detailed Jenkins configuration, see [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md)

## 🏗️ Infrastructure Setup

### 4. Deploy Infrastructure

```bash
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
```

### 5. Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 6. Install Kyverno

```bash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.10.0/install.yaml

# Apply custom policies
kubectl apply -f kyverno-policies/
```

### 7. Deploy ArgoCD Applications

```bash
# Apply ArgoCD application definitions
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-qa.yaml
kubectl apply -f argocd/application-prod.yaml
```

### 8. Trigger First Build

Push code to `dev`, `qa`, or `prod` branch. Jenkins webhook automatically triggers the pipeline:

```bash
git checkout dev
git push origin dev
```

## 📋 Infrastructure Modules

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

```hcl
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
```

## ⚙️ Pipeline Configuration

### Jenkins Parameters

When triggering a Jenkins build, provide these parameters:

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `ENVIRONMENT` | Choice | Target deployment environment | dev |
| `SKIP_TESTS` | Boolean | Skip Maven unit tests | false |
| `SKIP_SECURITY_SCAN` | Boolean | Skip Snyk security scanning | false |

### Customize Pipeline

Edit [Jenkinsfile](Jenkinsfile) to:
- Add custom validation steps
- Modify security thresholds
- Add integration tests
- Configure notifications
- Change stage behavior

## 🔄 Deployment Workflow

### Development Environment
- **Trigger:** Push to `dev` branch
- **Build:** Automatic via Jenkins webhook
- **Deployment:** Automatic to EKS dev cluster
- **ArgoCD Sync:** Automatic

### QA Environment
- **Trigger:** Push to `qa` branch
- **Build:** Automatic via Jenkins webhook
- **Deployment:** Manual approval required
- **Tests:** Available for QA team
- **ArgoCD Sync:** Automatic after approval

### Production Environment
- **Trigger:** Push to `prod` branch
- **Build:** Automatic via Jenkins webhook
- **Deployment:** Manual approval required (senior review)
- **ArgoCD Sync:** Manual (for additional safety)
- **Rollback:** Via ArgoCD UI

## 🔒 Security & Compliance

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

The [`Dockerfile`](Dockerfile) implements:
- Non-root user execution
- Multi-stage builds
- Minimal base image (JRE slim)
- Health checks
- No unnecessary privileges

## 🐛 Troubleshooting

### Common Issues

#### Jenkins Build Won't Start
- Verify Jenkins credentials are configured correctly
- Check GitHub webhook is pointing to correct Jenkins URL
- Verify Jenkins user has repository access

#### EKS Cluster Not Ready
```bash
aws eks describe-cluster --name cicd-pipeline-dev --region us-east-1
```

#### Worker Nodes Not Ready
```bash
kubectl get nodes
kubectl describe node <node-name>
```

#### Dockerfile Validation Failed
Update `Dockerfile` to pin package versions:
```dockerfile
RUN apt-get update && apt-get install -y curl=7.68.0-1 && rm -rf /var/lib/apt/lists/*
```

#### Snyk Scan Failures
```bash
mvn versions:display-dependency-updates
```

#### ArgoCD Not Syncing
```bash
argocd app sync cicd-demo-app-dev
```

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 📁 Project Structure

```
sre-project-2/
├── jenkins/                        # Jenkins Configuration
│   ├── Dockerfile                 # Jenkins Docker image
│   ├── docker-compose.yml         # Jenkins setup
│   ├── jenkins.yaml               # Jenkins Configuration as Code
│   ├── plugins.txt                # Required plugins
│   └── JENKINS_SETUP.md           # Setup documentation
├── terraform/                      # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   └── modules/
│       ├── vpc/
│       ├── eks/
│       └── ecr/
├── helm-chart/                     # Kubernetes Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
├── kyverno-policies/               # Security policies
├── argocd/                         # ArgoCD applications
├── scripts/                        # Helper scripts
├── src/                            # Sample Java app
├── Dockerfile                      # Application container image
├── Jenkinsfile                     # Jenkins pipeline definition
├── pom.xml                         # Maven config
└── README.md                       # This file
```

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add feature'`)
4. Push branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License.

## 📧 Support

For questions or issues:
- Create an issue in the repository
- Check [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md) for Jenkins-specific help
- Contact: devops@example.com

---

**Built with ❤️ by the DevOps Team**
**Jenkins CI/CD Edition**
#   S R E - P r o j e c t - 1 - D e v S e c O p s - A W S - E K S - J e n k i n s - A r g o c d  
 #   S R E - P r o j e c t - 2 - D e v S e c O p s - A W S - E K S - J e n k i n s - A r g o c d  
 