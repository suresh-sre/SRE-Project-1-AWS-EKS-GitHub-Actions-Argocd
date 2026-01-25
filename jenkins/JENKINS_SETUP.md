# Jenkins CI/CD Configuration Guide

## Overview

Jenkins is configured to replace GitHub Actions for this CI/CD pipeline. This guide covers the setup, configuration, and integration of Jenkins with AWS, Docker, and Kubernetes.

## Installation

### Prerequisites

- Java 11+ (OpenJDK or Oracle JDK)
- Git 2.0+
- Docker (for container builds)
- Maven 3.6+
- kubectl (for Kubernetes integration)
- AWS CLI v2

### Install Jenkins

#### Option 1: Docker

```bash
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name jenkins \
  jenkins/jenkins:lts-jdk11
```

#### Option 2: Ubuntu/Debian

```bash
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins
```

#### Option 3: Amazon Linux 2

```bash
sudo amazon-linux-extras install java-11-openjdk -y
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
sudo yum install jenkins -y
sudo systemctl start jenkins
```

### Initial Setup

1. Access Jenkins at `http://localhost:8080`
2. Retrieve initial admin password:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Complete setup wizard:
   - Install recommended plugins
   - Create first admin user
   - Configure Jenkins URL

## Required Plugins

Install these plugins via Manage Jenkins > Plugin Manager:

### Core Plugins
- **Git** - Git repository integration
- **GitHub** - GitHub webhook integration
- **Pipeline** - Jenkins Pipeline support
- **Blue Ocean** - Modern UI for pipelines

### Build Plugins
- **Maven Integration** - Maven build support
- **Docker** - Docker container support
- **Docker Pipeline** - Docker integration in pipelines

### Cloud & Deployment Plugins
- **AWS Steps** - AWS CloudFormation, EC2, etc.
- **Kubernetes** - Kubernetes pod agents
- **Kubernetes CLI** - kubectl integration
- **Helm** - Helm chart deployment

### Security & Scanning Plugins
- **OWASP Dependency-Check** - Dependency vulnerability scanning
- **SonarQube Scanner** - Code quality analysis
- **Snyk Security** - Snyk integration

### Notification Plugins
- **Email Extension** - Enhanced email notifications
- **Slack Notification** - Slack integration
- **GitHub Integration** - GitHub status updates

### Credential Plugins
- **Credentials Binding** - Bind credentials to environment variables
- **AWS Credentials** - AWS credential management

## Credential Configuration

Create the following credentials in Jenkins (Manage Jenkins > Manage Credentials):

### AWS Credentials

1. **AWS Access Key ID**
   - Type: Secret text
   - Secret: Your AWS access key ID
   - ID: `aws-access-key-id`

2. **AWS Secret Access Key**
   - Type: Secret text
   - Secret: Your AWS secret access key
   - ID: `aws-secret-access-key`

3. **AWS Account ID**
   - Type: Secret text
   - Secret: Your AWS account ID (123456789012)
   - ID: `aws-account-id`

### Git & Repository Credentials

4. **Git Repository URL**
   - Type: Secret text
   - Secret: `https://github.com/your-org/your-repo.git`
   - ID: `git-repository-url`

5. **Git Credentials**
   - Type: Username with password
   - Username: Your GitHub username
   - Password: GitHub personal access token
   - ID: `git-credentials`

### Security & Scanning

6. **Snyk API Token**
   - Type: Secret text
   - Secret: Your Snyk API token
   - ID: `snyk-api-token`

### ArgoCD Configuration

7. **ArgoCD Server**
   - Type: Secret text
   - Secret: `https://argocd.your-domain.com`
   - ID: `argocd-server`

8. **ArgoCD Token**
   - Type: Secret text
   - Secret: Your ArgoCD authentication token
   - ID: `argocd-token`

## Pipeline Job Creation

### Create Pipeline Job

1. Click "New Item"
2. Enter job name: `cicd-pipeline` (or your preferred name)
3. Select "Pipeline"
4. Click "OK"

### Configure Pipeline

In the job configuration:

1. **General**
   - Discard old builds: 30 days
   - Build timeout: 1 hour

2. **Build Triggers**
   - GitHub hook trigger for GITScm polling
   - Poll SCM: `H H(2-3) * * *` (daily check)

3. **Advanced Project Options**
   - Lightweight checkout (for better performance)

4. **Pipeline**
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: Use `git-repository-url` credential
   - Branch: `*/dev` (or `*/qa`, `*/prod` for other branches)
   - Script Path: `Jenkinsfile`

### Webhook Configuration

For automatic builds on code push:

1. In Jenkins job > Configure > Build Triggers
2. Check "GitHub hook trigger for GITScm polling"
3. In GitHub repository > Settings > Webhooks
4. Add webhook:
   - Payload URL: `http://jenkins-url:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Push events
   - Active: ✓

## System Configuration

### Configure System

1. Go to Manage Jenkins > Configure System

2. **GitHub**
   - GitHub Server: Add server
   - API URL: `https://api.github.com`
   - Credentials: Use GitHub credentials

3. **Kubernetes**
   - Kubernetes URL: Your EKS cluster endpoint
   - Kubernetes Namespace: `jenkins`
   - Jenkins URL: `http://jenkins.jenkins.svc.cluster.local:8080`

4. **Email Notification**
   - SMTP Server: Your mail server
   - Default user e-mail suffix: `@example.com`

5. **Jenkins URL**
   - Jenkins Location: `http://jenkins.your-domain.com/`

## Environment Variables

Configure global environment variables in Manage Jenkins > Configure System > Environment variables:

```
AWS_DEFAULT_REGION=us-east-1
SNYK_SEVERITY_THRESHOLD=high
DOCKER_REGISTRY_DOMAIN=<account-id>.dkr.ecr.us-east-1.amazonaws.com
HELM_CHART_REPO=oci://<account-id>.dkr.ecr.us-east-1.amazonaws.com/helm-charts
ARGOCD_APP_NAME_PREFIX=cicd-pipeline
```

## Node Configuration

### Install Build Agents

Jenkins agents can be Docker containers, Kubernetes pods, or EC2 instances.

#### Docker Agent

```bash
docker run -d --name jenkins-agent \
  -e JENKINS_URL=http://jenkins:8080 \
  -e JENKINS_AGENT_NAME=docker-agent \
  -e JENKINS_AGENT_SECRET=<secret-from-jenkins> \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/inbound-agent
```

#### Kubernetes Agent

Create RBAC for Jenkins in EKS:

```bash
kubectl create namespace jenkins
kubectl create serviceaccount jenkins -n jenkins
kubectl create clusterrolebinding jenkins-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=jenkins:jenkins
```

## Job Templates

### Multi-Branch Pipeline

Create multi-branch pipeline for handling dev, qa, prod branches:

1. New Item > Multibranch Pipeline
2. Configure branch sources (GitHub)
3. Branch discovery: All branches
4. Script path: `Jenkinsfile`

This automatically creates separate jobs for each branch matching the Jenkinsfile.

## Pipeline Stages Explained

### 1. Initialize
- Validates environment matches branch
- Sets up build metadata

### 2. Platform Check
- Verifies EKS cluster is healthy
- Checks worker nodes status
- Validates system components

### 3. Validate (Parallel)
- **Dockerfile**: Hadolint linting
- **Kubernetes**: kubeconform manifest validation
- **Kyverno Policies**: Security policy validation
- **SAST**: Snyk source code scanning

### 4. Build
- Maven clean package build
- Generates JAR/WAR artifacts
- Runs unit tests (unless skipped)

### 5. Package (Parallel)
- **Docker**: Build and push image to ECR
- **Helm**: Package and push chart to ECR

### 6. Container Security Scan
- Snyk scans Docker image for vulnerabilities
- Generates SBOM (Software Bill of Materials)

### 7. Promote to ArgoCD
- Updates GitOps config repository
- Triggers ArgoCD sync
- ArgoCD deploys to target environment

### 8. Approval Gates
- Manual approval required for QA
- Manual approval required for Production

### 9. Verify Deployment
- Checks ArgoCD application sync status
- Validates deployment in cluster

## Troubleshooting

### Build Failures

**Common Issues:**

1. **Credential Not Found**
   - Verify credentials exist in Jenkins
   - Check credential ID matches Jenkinsfile

2. **Docker Build Fails**
   - Ensure Jenkins user can access Docker socket
   - Check Docker daemon is running
   - Verify Docker registry credentials

3. **AWS Authentication Error**
   - Verify AWS credentials are correct
   - Check IAM permissions (ECR, EKS, S3)
   - Ensure credentials are not expired

4. **Kubernetes Connection Error**
   - Verify kubeconfig is configured
   - Check EKS cluster is accessible
   - Validate IAM role permissions

### Pipeline Performance

- Use lightweight checkout (reduces SCM overhead)
- Enable log retention policies
- Clean workspace after builds
- Use Docker caching for faster builds

## Backup & Recovery

### Backup Jenkins Configuration

```bash
# Backup Jenkins home directory
tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins/

# Or use Jenkins backup plugin
# Install "ThinBackup" plugin for automated backups
```

### Restore Jenkins

```bash
# Stop Jenkins
sudo systemctl stop jenkins

# Extract backup
tar -xzf jenkins-backup-<date>.tar.gz -C /

# Start Jenkins
sudo systemctl start jenkins
```

## Security Best Practices

1. **Enable SSL/TLS**
   - Configure HTTPS for Jenkins UI
   - Use valid SSL certificates

2. **Access Control**
   - Enable authentication (LDAP, OAuth, etc.)
   - Use Jenkins Security Realm
   - Implement role-based access control (RBAC)

3. **Credential Management**
   - Rotate credentials regularly
   - Use Jenkins Credentials System
   - Never hardcode secrets in Jenkinsfile

4. **Audit Logging**
   - Enable Jenkins audit logs
   - Monitor credential access
   - Review build logs regularly

5. **Network Security**
   - Restrict Jenkins access via firewall
   - Use VPN for remote access
   - Enable CSRF protection

## Monitoring & Logging

### Jenkins Logs

```bash
# View Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Or for Docker
docker logs -f jenkins
```

### Metrics

Monitor key metrics:
- Build success/failure rate
- Build duration trends
- Pipeline stage durations
- Agent utilization
- Error rates and patterns

## Next Steps

1. Create pipeline job from Jenkinsfile
2. Configure webhooks in code repository
3. Set up credentials
4. Run initial pipeline
5. Monitor and optimize

## Support & Documentation

- Jenkins Official: https://www.jenkins.io/
- Jenkins Handbook: https://www.jenkins.io/doc/book/
- Pipeline Documentation: https://www.jenkins.io/doc/book/pipeline/
