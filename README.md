# SRE Project 1: DevSecOps — AWS EKS CI/CD Pipeline

Enterprise-grade CI/CD pipeline combining Infrastructure as Code (IaC), GitOps, and DevSecOps practices for automated AWS EKS deployments using GitHub Actions and ArgoCD.

---

## 📑 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [CI/CD Pipeline Deep Dive](#cicd-pipeline-deep-dive)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Infrastructure Setup (Terraform)](#infrastructure-setup-terraform)
- [Helm Chart & Kubernetes Deployment](#helm-chart--kubernetes-deployment)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Security & Compliance](#security--compliance)
- [Environment Promotion Strategy](#environment-promotion-strategy)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Project Overview

This SRE project demonstrates a complete production-ready platform combining:

| Pillar | Description | Tools |
|--------|-------------|-------|
| **Infrastructure as Code** | Modular Terraform for AWS (VPC, EKS, ECR) | Terraform |
| **CI Pipeline** | Automated build, test, lint, and security scanning | GitHub Actions, Maven, Docker, Hadolint |
| **CD Pipeline** | Declarative, continuous GitOps deployment | ArgoCD, Helm |
| **Kubernetes Security** | Admission-time policy enforcement | Kyverno |
| **DevSecOps** | SAST + SCA vulnerability scanning | Snyk |
| **Container Registry** | Immutable image storage with scan-on-push | AWS ECR |

---

## Architecture

### High-Level Flow

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────┐     ┌──────────────┐
│ Code Commit │────▶│  GitHub Actions   │────▶│  Build & Test  │────▶│ Security Scan │
│  (dev/qa/   │     │  CI/CD Pipeline   │     │  Maven + Docker│     │  Snyk SAST/  │
│   prod)     │     │                  │     │               │     │  Container   │
└─────────────┘     └──────────────────┘     └───────────────┘     └──────┬───────┘
                                                                          │
                    ┌──────────────────┐     ┌───────────────┐     ┌──────▼───────┐
                    │    Monitoring     │◀────│  Kyverno       │◀────│  ECR Push +   │
                    │  CloudWatch Logs  │     │  Policy Gate   │     │  ArgoCD Sync  │
                    └──────────────────┘     └───────────────┘     └──────────────┘
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Cloud Provider** | AWS (us-east-1) | VPC, EKS, ECR, IAM, CloudWatch |
| **IaC** | Terraform (modular) | Provision VPC, EKS cluster, ECR repos |
| **CI Engine** | GitHub Actions | 6-stage automated pipeline |
| **Build Tool** | Maven + JDK 11 | Java application build (JAR/WAR) |
| **Containerization** | Docker (multi-stage) | Non-root, minimal base image |
| **Package Manager** | Helm | Kubernetes deployment packaging |
| **GitOps Engine** | ArgoCD | Automated sync from Git to cluster |
| **Policy Engine** | Kyverno | Kubernetes admission control |
| **Security Scanner** | Snyk | SAST (source code) + SCA (container) |
| **Auth Model** | AWS OIDC | Keyless GitHub → AWS authentication |

---

## CI/CD Pipeline Deep Dive

The pipeline is defined in `.github/workflows/cicd-pipeline.yml` and contains **6 stages with 10 jobs**. It triggers on **push** or **pull request** to the `dev`, `qa`, or `prod` branches.

### Pipeline Stages Overview

```
Stage 1: Platform Check          ──▶  Verify EKS cluster is healthy
Stage 2: Validate (4 parallel)   ──▶  Lint Dockerfile, validate K8s manifests, test Kyverno policies, Snyk SAST
Stage 3: Build Artifact           ──▶  Maven build → upload JAR/WAR
Stage 4: Package (2 sequential)  ──▶  Docker build + ECR push → Helm package + ECR push
Stage 5: Scan Container           ──▶  Snyk container vulnerability scan
Stage 6: Promote                  ──▶  Update Helm values → Git commit → ArgoCD auto-sync
```

### Job Dependency Graph

```
platform-check ─────────────────────────────────────────── (standalone)

validate-dockerfile ─────┐
validate-kubernetes ─────┤ (4 parallel, standalone)
validate-kyverno ────────┤
sast-snyk ───────────────┘

build-maven ──▶ package-docker ──┬──▶ package-helm ──┬──▶ promote
                                 │                    │
                                 └──▶ scan-container ─┘

approval-gate-qa ────────────────────────────────────────── (env-gated, QA only)
approval-gate-prod ──────────────────────────────────────── (env-gated, Prod only)
```

### Stage-by-Stage Breakdown

#### Stage 1 — Platform Check (`platform-check`)

Validates that the target EKS cluster is alive before the pipeline proceeds.

| Step | Action |
|------|--------|
| Configure AWS credentials | Authenticates via **OIDC** (`role-to-assume: GitHubActionsRole`) — no static keys |
| Install kubectl | Downloads latest stable kubectl binary |
| Update kubeconfig | Connects to cluster `cicd-pipeline-{branch}` (e.g., `cicd-pipeline-dev`) |
| Check EKS cluster status | Runs `scripts/check-eks-cluster.sh` to verify node health |

#### Stage 2 — Validate (4 Parallel Jobs)

Four independent validation jobs run simultaneously:

| Job | Tool | What It Checks |
|-----|------|---------------|
| `validate-dockerfile` | [Hadolint](https://github.com/hadolint/hadolint) v3.1.0 | Dockerfile best practices (ignores DL3008, DL3009) |
| `validate-kubernetes` | [kubeconform](https://github.com/yannh/kubeconform) | K8s manifest schema validation via `scripts/validate-k8s-manifests.sh` |
| `validate-kyverno-policies` | [Kyverno Action](https://github.com/nirmata/kyverno-action) v0.5.5 | Tests Kyverno policies against `helm-chart/templates/deployment.yaml` |
| `sast-snyk` | [Snyk Maven](https://github.com/snyk/actions) | Static Application Security Testing — fails on `high` severity |

> **Note:** Kyverno and Snyk jobs use `continue-on-error: true`, so failures are reported but won't block the pipeline.

#### Stage 3 — Build Artifact (`build-maven`)

| Step | Detail |
|------|--------|
| Set up JDK 11 | Uses `temurin` distribution with Maven caching enabled |
| Build with Maven | `mvn clean package -DskipTests` — produces JAR/WAR in `target/` |
| Upload artifacts | Stores build output as GitHub artifact (1-day retention) |

#### Stage 4 — Package (`package-docker` → `package-helm`)

**Docker Packaging** (depends on `build-maven`):

| Step | Detail |
|------|--------|
| Download Maven artifacts | Retrieves JAR/WAR from Stage 3 |
| Configure AWS OIDC | Authenticates to AWS |
| Login to ECR | `aws-actions/amazon-ecr-login@v2` |
| Build Docker image | Tags with `{sha}`, `latest`, and `{branch}-{sha}` |
| Push to ECR | Pushes all 3 tags to `cicd-pipeline-{env}-app-backend` |

**ECR Repository Naming Convention:**
```
{account_id}.dkr.ecr.us-east-1.amazonaws.com/cicd-pipeline-{env}-app-backend
```

**Helm Packaging** (depends on `package-docker`):

| Step | Detail |
|------|--------|
| Set up Helm | Latest version via `azure/setup-helm@v3` |
| Login to ECR (Helm) | OCI registry login for Helm charts |
| Package & push | Packages chart with git SHA as version, pushes to `oci://{account_id}.dkr.ecr.../helm-charts` |

#### Stage 5 — Scan Container (`scan-container`)

| Step | Detail |
|------|--------|
| Pull image from ECR | Pulls the exact image built in Stage 4 |
| Snyk container scan | Scans for OS and application-level vulnerabilities (threshold: `high`) |
| Snyk monitor | Registers the image for continuous monitoring on Snyk dashboard |

> Uses `continue-on-error: true` — scan results are advisory, not blocking.

#### Stage 6 — Promote (`promote`)

| Step | Detail |
|------|--------|
| Configure Git | Sets CI bot identity (`ci-cd@github.com`) |
| Run promotion script | `scripts/update-config-repo.sh` updates `helm-chart/values-{env}.yaml` with new image tag |
| Git commit & push | Commits the values change back to the same branch |
| ArgoCD sync check | Pings ArgoCD API to verify the deployment is syncing |

**How the promotion script works:**
1. Updates `image.repository` and `image.tag` in the environment-specific Helm values file
2. Commits with a descriptive message including actor, pipeline URL, and commit SHA
3. Pushes to the branch — ArgoCD detects the change and auto-syncs

#### Manual Approval Gates

| Gate | Condition | GitHub Environment |
|------|----------|-------------------|
| `approval-gate-qa` | Push to `qa` branch | `qa` (requires reviewer approval) |
| `approval-gate-prod` | Push to `prod` branch | `prod` (requires reviewer approval) |

These use GitHub's **Environment Protection Rules** — the pipeline pauses and waits for a designated reviewer to approve before deployment proceeds.

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ACCOUNT_ID` | AWS account ID for ECR registry URL construction |
| `SNYK_TOKEN` | API token for Snyk security scanning |

### Required GitHub OIDC Configuration

The pipeline uses **keyless OIDC authentication** instead of static AWS keys. This requires:
- An IAM Role `GitHubActionsRole` (ARN: `arn:aws:iam::471112966640:role/GitHubActionsRole`)
- A trust policy allowing GitHub's OIDC provider to assume the role
- Permissions: `id-token: write` in workflow job permissions

---

## Getting Started

### Prerequisites

| Requirement | Details |
|-------------|---------|
| **AWS Account** | Permissions for EC2, VPC, EKS, ECR, IAM, S3, DynamoDB |
| **CLI Tools** | Terraform ≥ 1.0, AWS CLI v2, kubectl, Docker, Maven, Helm 3 |
| **GitHub** | Repository with Actions enabled + Environments configured |
| **Snyk Account** | Free tier or above — API token required |

### Step 1: Setup AWS Infrastructure

```bash
cd terraform
terraform init
terraform plan -var="environment=dev"
terraform apply -var="environment=dev"
```

This creates:
- VPC with 3 public + 3 private subnets across 3 AZs (`10.0.0.0/16`)
- EKS cluster (`cicd-pipeline-dev`) with managed node groups (2× `t3.medium`)
- ECR repositories (`app-backend`, `app-frontend`) with scan-on-push
- IAM roles, security groups, OIDC provider for IRSA

### Step 2: Install ArgoCD on EKS

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI (port-forward)
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### Step 3: Deploy Kyverno Policies

```bash
# Install Kyverno
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.9.0/install.yaml

# Apply project policies
kubectl apply -f kyverno-policies/

# Verify
kubectl get clusterpolicy
```

### Step 4: Configure GitHub Repository

1. **Secrets** → Settings → Secrets and Variables → Actions:
   - `AWS_ACCOUNT_ID` — Your 12-digit AWS account ID
   - `SNYK_TOKEN` — From Snyk account settings

2. **OIDC** → Create IAM Role `GitHubActionsRole` with trust policy for `token.actions.githubusercontent.com`

3. **Environments** → Create `qa` and `prod` environments with required reviewers

### Step 5: Deploy Application

```bash
# Create ArgoCD applications
kubectl apply -f argocd/application-dev.yaml
kubectl apply -f argocd/application-qa.yaml
kubectl apply -f argocd/application-prod.yaml

# Trigger pipeline
git push origin dev
```

---

## Project Structure

```
SRE-Project-1/
├── .github/workflows/
│   └── cicd-pipeline.yml          # 6-stage CI/CD pipeline (GitHub Actions)
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # Root module — orchestrates VPC, EKS, ECR
│   ├── variables.tf                # Input variables with validation
│   ├── outputs.tf                  # Output values (cluster endpoint, ECR URLs)
│   ├── backend.tf                  # S3 + DynamoDB remote state backend
│   └── modules/
│       ├── vpc/                    # VPC, subnets, NAT, IGW, route tables
│       ├── eks/                    # EKS cluster, node groups, OIDC, add-ons
│       └── ecr/                    # ECR repos, lifecycle policies, encryption
│
├── helm-chart/                     # Kubernetes deployment chart
│   ├── Chart.yaml                  # Chart metadata
│   ├── values.yaml                 # Default values
│   ├── values-dev.yaml             # Dev overrides (2 replicas, DEBUG logging)
│   ├── values-prod.yaml            # Prod overrides
│   └── templates/
│       ├── deployment.yaml         # Pod spec with health checks
│       ├── service.yaml            # ClusterIP/LoadBalancer service
│       ├── ingress.yaml            # ALB ingress rules
│       └── hpa.yaml                # Horizontal Pod Autoscaler
│
├── kyverno-policies/               # Kubernetes admission policies
│   ├── restrict-privileged-pods.yaml
│   ├── require-resource-limits.yaml
│   └── disallow-host-namespaces.yaml
│
├── argocd/                         # GitOps application definitions
│   ├── application-dev.yaml        # Dev: auto-sync, self-heal, prune
│   ├── application-qa.yaml         # QA: auto-sync with approval gate
│   └── application-prod.yaml       # Prod: manual sync with approval gate
│
├── scripts/                        # Pipeline helper scripts
│   ├── check-eks-cluster.sh        # Validates EKS node/pod health
│   ├── validate-k8s-manifests.sh   # Runs kubeconform validation
│   └── update-config-repo.sh       # Updates Helm values + git push for ArgoCD
│
├── src/                            # Java application source code
│   └── main/java/com/example/
│       └── App.java
│
├── Dockerfile                      # Multi-stage: maven build → temurin JRE runtime
├── pom.xml                         # Maven project configuration (JDK 11)
├── trust-policy.json               # IAM OIDC trust policy for GitHub Actions
└── WALKTHROUGH.md                  # Step-by-step detailed setup guide
```

---

## Infrastructure Setup (Terraform)

### Module Architecture

```
terraform/main.tf
    │
    ├── module "vpc"  ──▶  VPC, 3 public + 3 private subnets, NAT, IGW
    │
    ├── module "eks"  ──▶  EKS cluster, node groups, OIDC, add-ons
    │
    └── module "ecr"  ──▶  ECR repositories, scan-on-push, lifecycle policies
```

### VPC Module (`terraform/modules/vpc/`)

| Resource | Configuration |
|----------|--------------|
| VPC | `10.0.0.0/16` CIDR block |
| Public Subnets | `10.0.101.0/24`, `10.0.102.0/24`, `10.0.103.0/24` (one per AZ) |
| Private Subnets | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` (worker nodes) |
| NAT Gateways | Outbound internet for private subnets |
| Internet Gateway | Inbound access for public subnets |
| Tags | EKS-specific tags for AWS Load Balancer Controller |

### EKS Module (`terraform/modules/eks/`)

| Resource | Configuration |
|----------|--------------|
| Control Plane | Kubernetes `1.34`, logging enabled |
| Node Groups | `general`: 2 desired / 1 min / 4 max × `t3.medium` ON_DEMAND, 20GB disk |
| OIDC Provider | Enables IRSA (IAM Roles for Service Accounts) |
| Add-ons | VPC CNI, CoreDNS, kube-proxy, EBS CSI Driver |

### ECR Module (`terraform/modules/ecr/`)

| Resource | Configuration |
|----------|--------------|
| Repositories | `app-backend`, `app-frontend` (per environment) |
| Security | Scan-on-push enabled, encryption at rest |
| Lifecycle | Retains last 30 images, auto-cleans untagged |

### Deploy Commands

```bash
# Create S3 backend bucket
aws s3 mb s3://terraform-state-cicd-pipeline-1 --region us-east-1

# Initialize, plan, apply
cd terraform
terraform init
terraform plan -var="environment=dev" -out=tfplan
terraform apply tfplan

# Connect to cluster
aws eks update-kubeconfig --region us-east-1 --name cicd-pipeline-dev
kubectl cluster-info
kubectl get nodes
```

---

## Helm Chart & Kubernetes Deployment

### Environment-Specific Values

| Setting | Dev | Prod |
|---------|-----|------|
| Replicas | 2 | 3+ |
| CPU Limit | 500m | 1000m |
| Memory Limit | 512Mi | 1Gi |
| Log Level | DEBUG | INFO |
| Ingress Host | `dev.example.com` | `prod.example.com` |

### Dockerfile (Multi-Stage)

```dockerfile
# Stage 1: Build
FROM maven:3.8-eclipse-temurin-11 AS builder
# Compiles Java source to JAR

# Stage 2: Runtime
FROM eclipse-temurin:11-jre-focal
# Non-root user (appuser), health check on :8080/actuator/health
# JVM tuned for containers: UseContainerSupport, 75% MaxRAM, G1GC
```

**Security features:** Non-root user, minimal JRE base image, health checks, container-aware JVM flags.

---

## GitOps with ArgoCD

### How It Works

1. **Pipeline** updates `helm-chart/values-{env}.yaml` with new image tag
2. **Pipeline** commits and pushes the change to the branch
3. **ArgoCD** detects the Git change (polling or webhook)
4. **ArgoCD** renders the Helm chart with updated values
5. **ArgoCD** applies the manifests to the target EKS namespace
6. **Kyverno** validates the deployment at admission time

### ArgoCD Application Configuration (Dev)

| Setting | Value |
|---------|-------|
| Source Repo | `https://github.com/suresh-sre/SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd.git` |
| Target Branch | `dev` |
| Helm Values | `values-dev.yaml` |
| Destination Namespace | `dev` |
| Auto Sync | ✅ Enabled (prune + self-heal) |
| Create Namespace | ✅ Enabled |
| Retry | 5 attempts, exponential backoff (5s → 3m) |
| Revision History | Last 10 |

---

## Security & Compliance

### Kyverno Policies (Admission Control)

| Policy | What It Enforces |
|--------|-----------------|
| `restrict-privileged-pods.yaml` | Blocks `privileged: true`, `allowPrivilegeEscalation`, enforces non-root |
| `require-resource-limits.yaml` | Requires CPU/memory requests and limits on all containers |
| `disallow-host-namespaces.yaml` | Blocks `hostPID`, `hostIPC`, `hostNetwork` access |

### Security Scanning Layers

| Layer | When | Tool | Threshold |
|-------|------|------|-----------|
| **SAST** (Source Code) | Stage 2 | Snyk Maven | `high` severity |
| **Container Image** | Stage 5 | Snyk Docker | `high` severity |
| **ECR Push Scan** | On push | AWS ECR native | All severabilities |
| **Admission Control** | Deploy time | Kyverno | Policy-defined |
| **Continuous Monitoring** | Ongoing | Snyk Monitor | Dashboard alerts |

### Best Practices Implemented

| Category | Implementation |
|----------|---------------|
| **Container** | Non-root user, minimal base image (JRE only), multi-stage builds |
| **Kubernetes** | Resource limits enforced, health checks, HPA, pod disruption budgets |
| **Network** | Private subnets for workers, NACLs, security groups, NAT gateway |
| **IAM** | OIDC keyless auth, IRSA, least-privilege roles, audit logging |
| **GitOps** | Declarative config, auto-sync with self-heal, revision history |

---

## Environment Promotion Strategy

| Environment | Branch | Auto Deploy | Approval Required | ArgoCD Sync |
|------------|--------|------------|-------------------|-------------|
| **Development** | `dev` | ✅ Yes | ❌ No | Automatic |
| **QA** | `qa` | ✅ Yes | ✅ Required | Automatic |
| **Production** | `prod` | ✅ Yes | ✅ Required | Manual |

### Promotion Workflow

```bash
# 1. Develop on dev branch
git checkout dev
git add . && git commit -m "Add feature"
git push origin dev
# → Pipeline runs → auto-deploys to dev cluster

# 2. Promote to QA (merge or push to qa)
git checkout qa && git merge dev
git push origin qa
# → Pipeline runs → waits for QA approval → deploys

# 3. Promote to Prod (merge or push to prod)
git checkout prod && git merge qa
git push origin prod
# → Pipeline runs → waits for Prod approval → deploys

# 4. Monitor
kubectl -n dev get pods
kubectl -n qa get pods
kubectl -n default get svc
```

---

## Troubleshooting

### Terraform State Lock Error

```bash
# If you see "Error acquiring the state lock":
terraform force-unlock <LOCK_ID>
# Example: terraform force-unlock af40c91f-887c-c15b-d07b-bc051f1ce40f
```

### EKS Cluster Issues

```bash
aws eks describe-cluster --name cicd-pipeline-dev --region us-east-1
kubectl get events --all-namespaces
kubectl get nodes -o wide
kubectl describe node <node-name>
aws logs tail /aws/eks/cicd-pipeline-dev/cluster --follow
```

### ArgoCD Deployment Issues

```bash
argocd app get cicd-demo-app-dev
argocd app sync cicd-demo-app-dev
kubectl logs -n argocd deployment/argocd-application-controller
```

### Kyverno Policy Violations

```bash
kubectl get clusterpolicy
kubectl describe clusterpolicy restrict-privileged
kubectl get events --field-selector reason=PolicyViolation
kubectl logs -n kyverno deployment/kyverno
```

### GitHub Actions Pipeline Failures

1. **Check workflow logs**: GitHub → Actions → Select workflow → View logs
2. **Validate credentials**: Verify OIDC role trust policy and `AWS_ACCOUNT_ID` secret
3. **Check Snyk token**: Ensure `SNYK_TOKEN` is valid in repository secrets
4. **Verify AWS permissions**: IAM role needs EKS, ECR, S3 access
5. **Test locally**: Run the same Maven/Docker commands in your terminal

---

## Contributing

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit: `git commit -m "Add feature"`
3. Push branch: `git push origin feature/my-feature`
4. Open Pull Request for review
5. After merge to `dev`, pipeline automatically deploys

---

## Documentation

- [WALKTHROUGH.md](WALKTHROUGH.md) — Step-by-step setup guide
- [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — Detailed implementation notes
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — Common issues and fixes

## License

MIT License

## Support

For issues or questions:
- Open a GitHub Issue
- Review CloudWatch logs
- Check the documentation files above

---

**Last Updated:** April 2026
**Maintained by:** [suresh-sre](https://github.com/suresh-sre)
