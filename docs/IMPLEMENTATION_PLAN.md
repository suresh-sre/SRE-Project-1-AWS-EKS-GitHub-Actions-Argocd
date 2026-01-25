# DevOps CI/CD Pipeline Implementation Plan - Jenkins Edition

This implementation creates a production-ready CI/CD pipeline using Jenkins for deploying applications to AWS EKS with comprehensive security scanning, policy enforcement, and GitOps-based deployment using ArgoCD.

## User Review Required

> [!IMPORTANT]
> **Technology Stack Confirmation**
> - **CI/CD Platform**: Jenkins (Declarative Pipeline)
> - **Container Registry**: AWS ECR
> - **Kubernetes**: AWS EKS
> - **GitOps Tool**: ArgoCD
> - **Security Scanning**: Snyk (requires API token)
> - **Policy Engine**: Kyverno
> - **Build Tool**: Maven (for Java applications)
> - **Package Manager**: Helm 3

> [!WARNING]
> **Required Credentials & Tokens**
> - AWS credentials with EKS, ECR, VPC permissions
> - Git repository credentials (SSH key or HTTPS token)
> - Snyk API token for security scanning
> - ArgoCD authentication token
> - Jenkins installed and configured

## Proposed Changes

### 1. Jenkins CI/CD Pipeline Infrastructure

#### [NEW] [Jenkinsfile](Jenkinsfile)
Declarative Jenkins pipeline implementing all CI/CD stages:
- **Stage 1**: Initialize - Environment validation
- **Stage 2**: Platform Check - EKS cluster health
- **Stage 3**: Validate - Parallel validation stages (Dockerfile, K8s, Kyverno, Snyk)
- **Stage 4**: Build - Maven build and artifact generation
- **Stage 5**: Package - Parallel Docker and Helm packaging
- **Stage 6**: Container Scan - Snyk vulnerability scanning
- **Stage 7**: Promote - GitOps deployment to ArgoCD
- **Stage 8**: Approval Gates - Manual approvals for QA/Prod
- **Stage 9**: Verify - ArgoCD sync status verification

#### [NEW] [jenkins/](jenkins/) Directory
Complete Jenkins configuration and setup files:

##### [NEW] [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md)
Comprehensive guide for:
- Jenkins installation (Docker, Kubernetes, traditional)
- Required plugins installation
- Credential configuration
- Pipeline job creation
- Webhook setup for automatic builds
- System configuration
- Node configuration
- Security best practices

##### [NEW] [jenkins/Dockerfile](jenkins/Dockerfile)
Custom Jenkins Docker image with:
- All required build tools (Maven, kubectl, Helm, AWS CLI)
- Docker CLI for container builds
- Security scanning tools (Snyk, kubeconform, hadolint, kyverno)
- JCasC support for automation

##### [NEW] [jenkins/docker-compose.yml](jenkins/docker-compose.yml)
Docker Compose file for:
- Easy Jenkins deployment in development/testing
- PostgreSQL database for job storage
- Docker-in-Docker for agent
- Volume management
- Network configuration
- Environment variable setup

##### [NEW] [jenkins/jenkins.yaml](jenkins/jenkins.yaml)
Jenkins Configuration as Code (JCasC) for:
- System settings and security
- Credentials management (AWS, Git, Snyk, ArgoCD)
- Tool configurations (Git, Maven, JDK)
- Kubernetes cloud integration
- Email and Slack notifications

##### [NEW] [jenkins/plugins.txt](jenkins/plugins.txt)
Complete list of required Jenkins plugins:
- Pipeline plugins
- Git and GitHub integration
- Docker and Kubernetes support
- AWS integration
- Security scanning (Snyk)
- Notification plugins

### 2. Infrastructure as Code (Terraform)

#### [EXISTING] [terraform/](terraform/)
Complete Terraform infrastructure for AWS EKS cluster, networking, and supporting services.

##### [EXISTING] [main.tf](terraform/main.tf)
Root Terraform configuration with provider setup and module orchestration.

##### [EXISTING] [variables.tf](terraform/variables.tf)
Input variables for environment configuration (dev, qa, prod).

##### [EXISTING] [outputs.tf](terraform/outputs.tf)
Output values for EKS cluster endpoint, ECR repository URLs, and cluster details.

##### [EXISTING] [backend.tf](terraform/backend.tf)
S3 backend configuration for Terraform state management.

##### [EXISTING] [terraform/modules/eks/main.tf](terraform/modules/eks/main.tf)
EKS cluster, node groups, and IAM roles for service accounts.

##### [EXISTING] [terraform/modules/vpc/main.tf](terraform/modules/vpc/main.tf)
VPC, subnets, route tables, internet gateway, and NAT gateway configuration.

##### [EXISTING] [terraform/modules/ecr/main.tf](terraform/modules/ecr/main.tf)
ECR repository creation with scan-on-push and lifecycle policies.

### 3. Application Components

#### [EXISTING] [Dockerfile](Dockerfile)
Multi-stage Dockerfile for Java application with security best practices.

#### [EXISTING] [pom.xml](pom.xml)
Maven project configuration for Java application build.

#### [EXISTING] [src/](src/)
Sample Java application source code with Spring Boot REST API.

### 4. Kubernetes Configuration

#### [EXISTING] [helm-chart/](helm-chart/)
Helm chart for Kubernetes deployment with configurable values.

##### [EXISTING] [Chart.yaml](helm-chart/Chart.yaml)
Helm chart metadata and version information.

##### [EXISTING] [values.yaml](helm-chart/values.yaml)
Default configuration values for deployment, service, ingress, resources.

##### [EXISTING] [values-dev.yaml](helm-chart/values-dev.yaml)
Development environment configuration overrides.

##### [EXISTING] [values-qa.yaml](helm-chart/values-qa.yaml)
QA environment configuration overrides.

##### [EXISTING] [values-prod.yaml](helm-chart/values-prod.yaml)
Production environment configuration overrides.

##### [EXISTING] [templates/deployment.yaml](helm-chart/templates/deployment.yaml)
Kubernetes Deployment manifest with resource limits and health checks.

##### [EXISTING] [templates/service.yaml](helm-chart/templates/service.yaml)
Kubernetes Service manifest.

##### [EXISTING] [templates/ingress.yaml](helm-chart/templates/ingress.yaml)
Kubernetes Ingress manifest for external access with TLS.

##### [EXISTING] [templates/configmap.yaml](helm-chart/templates/configmap.yaml)
ConfigMap for application configuration.

### 5. Security Policies

#### [EXISTING] [kyverno-policies/](kyverno-policies/)
Kyverno policy definitions for security and compliance.

##### [EXISTING] [restrict-privileged-pods.yaml](kyverno-policies/restrict-privileged-pods.yaml)
Policy to prevent creation of privileged containers.

##### [EXISTING] [require-resource-limits.yaml](kyverno-policies/require-resource-limits.yaml)
Policy to enforce CPU and memory limits on all pods.

##### [EXISTING] [disallow-host-namespaces.yaml](kyverno-policies/disallow-host-namespaces.yaml)
Policy to prevent host namespace access.

### 6. GitOps Configuration

#### [EXISTING] [argocd/](argocd/)
ArgoCD application definitions for GitOps deployment.

##### [EXISTING] [application-dev.yaml](argocd/application-dev.yaml)
ArgoCD Application manifest for dev environment with auto-sync.

##### [EXISTING] [application-qa.yaml](argocd/application-qa.yaml)
ArgoCD Application manifest for QA environment with auto-sync.

##### [EXISTING] [application-prod.yaml](argocd/application-prod.yaml)
ArgoCD Application manifest for production with manual sync.

### 7. Helper Scripts

#### [EXISTING] [scripts/check-eks-cluster.sh](scripts/check-eks-cluster.sh)
Script to validate EKS cluster health and node readiness.

#### [EXISTING] [scripts/validate-k8s-manifests.sh](scripts/validate-k8s-manifests.sh)
Script to validate Kubernetes YAML syntax using kubeconform.

#### [EXISTING] [scripts/update-config-repo.sh](scripts/update-config-repo.sh)
Script to update GitOps configuration repository with new image/chart versions.

### 8. Documentation

#### [UPDATED] [README.md](README.md)
Updated for Jenkins CI/CD pipeline:
- Architecture overview with Jenkins pipeline
- Pipeline stages explanation
- Quick start guide with Jenkins deployment options
- Prerequisites and credential configuration
- Jenkins setup instructions
- Deployment workflow for each environment

#### [UPDATED] [WALKTHROUGH.md](WALKTHROUGH.md)
Updated project walkthrough with Jenkins implementation details.

#### [THIS FILE] [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)
Comprehensive implementation guide for Jenkins CI/CD.

#### [EXISTING] [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
Troubleshooting guide for common issues and recovery procedures.

##### [NEW] [update-config-repo.sh](file:///d:/learning/sre-project-1/scripts/update-config-repo.sh)
Script to update config.yaml in GitOps repository (Stage 6).

---

### Sample Application

#### [NEW] [src/main/java/com/example/App.java](file:///d:/learning/sre-project-1/src/main/java/com/example/App.java)
Sample Java application for demonstration.

#### [NEW] [pom.xml](file:///d:/learning/sre-project-1/pom.xml)
Maven POM file for building the Java application.

---

### Documentation

#### [NEW] [README.md](file:///d:/learning/sre-project-1/README.md)
Comprehensive documentation covering:
- Pipeline stages overview
- Infrastructure setup instructions
- CI/CD configuration
- Deployment workflow
- Troubleshooting guide
- Prerequisites and requirements

#### [NEW] [docs/TROUBLESHOOTING.md](file:///d:/learning/sre-project-1/docs/TROUBLESHOOTING.md)
Detailed troubleshooting guide for common issues in each pipeline stage.

## Verification Plan

### Automated Tests
1. **Terraform Validation**: Run `terraform validate` and `terraform plan` for all modules
2. **Workflow Syntax**: Validate `.github/workflows/cicd-pipeline.yml` syntax
3. **Helm Chart Validation**: Run `helm lint helm-chart/` to validate chart structure
4. **Kubernetes Manifest Validation**: Use `kubeval` or `kubeconform` on generated manifests

### Manual Verification
1. **Infrastructure Deployment**: Deploy Terraform infrastructure to a test AWS account
2. **Workflow Execution**: Push to dev/qa/prod branch and verify all jobs complete successfully
3. **ArgoCD Integration**: Verify ArgoCD detects and deploys the application
4. **Security Scanning**: Confirm Snyk reports are generated for both SAST and container scanning
5. **Policy Enforcement**: Test Kyverno policies by attempting to create non-compliant resources
