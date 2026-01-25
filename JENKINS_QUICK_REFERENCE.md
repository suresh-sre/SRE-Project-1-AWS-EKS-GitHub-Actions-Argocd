# Jenkins CI/CD Quick Reference Guide

## Overview

This project has been successfully converted from GitHub Actions to Jenkins for CI/CD pipeline management. All documentation and configuration files have been updated to reflect the Jenkins implementation.

## What Changed

### Removed (GitHub Actions)
- `.github/workflows/cicd-pipeline.yml` - GitHub Actions workflow
- GitHub Actions-specific secrets and credentials

### Added (Jenkins)
- `Jenkinsfile` - Declarative Jenkins pipeline
- `jenkins/` directory with complete Jenkins setup:
  - `JENKINS_SETUP.md` - Comprehensive Jenkins configuration guide
  - `Dockerfile` - Custom Jenkins Docker image
  - `docker-compose.yml` - Easy Jenkins deployment
  - `jenkins.yaml` - Jenkins Configuration as Code (JCasC)
  - `plugins.txt` - Required Jenkins plugins list

### Updated Documentation
- `README.md` - Updated with Jenkins architecture and setup
- `WALKTHROUGH.md` - Updated to reference Jenkins components
- `docs/IMPLEMENTATION_PLAN.md` - Jenkins-based implementation plan

## Quick Start

### 1. Deploy Jenkins (< 5 minutes)

```bash
cd jenkins
docker-compose up -d
```

Then access Jenkins at `http://localhost:8080`

### 2. Configure Credentials (< 10 minutes)

Go to **Manage Jenkins → Manage Credentials** and add:
- `aws-access-key-id` - Your AWS access key
- `aws-secret-access-key` - Your AWS secret key
- `aws-account-id` - Your AWS account ID
- `git-credentials` - Git repository credentials
- `snyk-api-token` - Snyk API token
- `argocd-server` - ArgoCD server URL
- `argocd-token` - ArgoCD authentication token

### 3. Create Pipeline Job (< 5 minutes)

1. Click "New Item"
2. Name: `cicd-pipeline`
3. Type: **Pipeline**
4. Configuration:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository: Your Git repo URL
   - Branch: `*/dev` (or `*/qa`, `*/prod`)
   - Script Path: `Jenkinsfile`

### 4. Configure Webhook (< 5 minutes)

In GitHub/GitLab → Settings → Webhooks:
- URL: `http://jenkins-url:8080/github-webhook/`
- Content type: `application/json`
- Events: Push events
- Active: ✓

### 5. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply -var="environment=dev"
```

### 6. Trigger First Build

```bash
git push origin dev
```

Jenkins webhook automatically triggers the pipeline!

## Pipeline Stages

| Stage | Purpose | Tools |
|-------|---------|-------|
| **Initialize** | Validate environment | Bash |
| **Platform Check** | Verify EKS cluster | kubectl, AWS CLI |
| **Validate** (Parallel) | Code & config validation | Hadolint, kubeconform, Snyk, Kyverno |
| **Build** | Maven build | Maven, Java |
| **Package** (Parallel) | Docker & Helm packaging | Docker, Helm |
| **Container Scan** | Vulnerability scanning | Snyk |
| **Promote** | Update GitOps repo | Git, ArgoCD |
| **Approval Gates** | Manual approval | Jenkins UI |
| **Verify** | Check deployment status | kubectl, ArgoCD CLI |

## Jenkinsfile Highlights

### Pipeline Parameters

```groovy
parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'qa', 'prod'])
    booleanParam(name: 'SKIP_TESTS', defaultValue: false)
    booleanParam(name: 'SKIP_SECURITY_SCAN', defaultValue: false)
}
```

### Parallel Execution

```groovy
stage('Validate') {
    parallel {
        stage('Validate Dockerfile') { ... }
        stage('Validate Kubernetes') { ... }
        stage('Validate Kyverno Policies') { ... }
        stage('SAST Security Scan') { ... }
    }
}
```

### Environment-Based Deployment

```groovy
environment {
    IMAGE_TAG = "${GIT_COMMIT_SHORT}-${BUILD_TIMESTAMP}"
    DOCKER_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
}
```

### Approval Gates

```groovy
stage('Approval Gate - Production') {
    when { expression { ENVIRONMENT == 'prod' } }
    steps {
        timeout(time: 24, unit: 'HOURS') {
            input message: 'Approve deployment to PRODUCTION?', ok: 'Deploy'
        }
    }
}
```

## Credentials Required in Jenkins

| Credential ID | Type | Purpose |
|--------------|------|---------|
| `aws-access-key-id` | Secret text | AWS authentication |
| `aws-secret-access-key` | Secret text | AWS authentication |
| `aws-account-id` | Secret text | AWS account identification |
| `git-repository-url` | Secret text | Git repository URL |
| `git-credentials` | Username/Password | Git authentication |
| `snyk-api-token` | Secret text | Snyk security scanning |
| `argocd-server` | Secret text | ArgoCD server URL |
| `argocd-token` | Secret text | ArgoCD authentication |

## Key Commands

### Start Jenkins
```bash
cd jenkins
docker-compose up -d
```

### Check Jenkins Logs
```bash
docker-compose logs -f jenkins
```

### Stop Jenkins
```bash
docker-compose down
```

### Backup Jenkins Configuration
```bash
docker exec jenkins tar czf - /var/jenkins_home | gzip > jenkins-backup.tar.gz
```

### Monitor Pipeline
- **Web UI**: http://localhost:8080
- **Blue Ocean UI**: http://localhost:8080/blue/
- **Build Logs**: Jenkins UI → Build → Console Output

## Troubleshooting

### Jenkins won't start
```bash
docker-compose logs jenkins
```

### Build hangs on approval gate
- Check Jenkins configuration > Build Timeout settings
- Ensure timeout is > 24 hours for prod approvals

### Docker build fails
- Verify Docker daemon is running
- Check Jenkins user has Docker socket access
- Ensure Docker credentials are correct

### ArgoCD deployment doesn't sync
- Verify ArgoCD token is correct
- Check ArgoCD server URL is accessible
- Ensure GitOps config repository is reachable

## Performance Tips

1. **Enable Docker layer caching** in Jenkinsfile
2. **Use Maven cache** for faster builds
3. **Parallel stages** - Take advantage of parallel validation and packaging
4. **Use lightweight checkout** - Reduces Git overhead
5. **Prune Docker images** - Clean up old layers

## Security Best Practices

1. **Use Jenkins credentials** - Never hardcode secrets
2. **Enable SSL/TLS** - Use HTTPS for Jenkins UI
3. **Restrict job access** - Use Jenkins role-based security
4. **Audit logs** - Enable Jenkins audit trail plugin
5. **Keep plugins updated** - Regular plugin updates
6. **Run Jenkins as non-root** - Use Docker security best practices

## Next Steps

1. **Read [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md)** for detailed configuration
2. **Configure CI/CD environment** in your infrastructure
3. **Test pipeline** with a dev branch push
4. **Monitor builds** in Jenkins Blue Ocean UI
5. **Optimize pipeline** based on build times

## Documentation Map

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Project overview and quick start |
| [Jenkinsfile](Jenkinsfile) | Pipeline definition |
| [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md) | Detailed Jenkins setup |
| [jenkins/jenkins.yaml](jenkins/jenkins.yaml) | Jenkins Configuration as Code |
| [WALKTHROUGH.md](WALKTHROUGH.md) | Project components walkthrough |
| [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) | Implementation roadmap |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Troubleshooting guide |

## Support

For issues or questions:
1. Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Review Jenkins logs: `docker-compose logs jenkins`
3. Check pipeline logs in Jenkins UI
4. Consult [jenkins/JENKINS_SETUP.md](jenkins/JENKINS_SETUP.md)

---

**Jenkins CI/CD Implementation Complete!**
Ready to deploy to AWS EKS with GitOps and comprehensive security scanning.
