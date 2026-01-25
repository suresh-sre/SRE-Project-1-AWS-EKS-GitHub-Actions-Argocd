# Jenkins Dockerfile for CI/CD Pipeline
# Includes all necessary tools and plugins for the pipeline

FROM jenkins/jenkins:lts-jdk11

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    jq \
    python3 \
    python3-pip \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (without daemon since we'll use socket mounting)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws/

# Install Snyk CLI
RUN npm install -g snyk

# Install kubeconform
RUN curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz \
    && mv kubeconform /usr/local/bin/

# Install Hadolint
RUN curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 -o hadolint \
    && chmod +x hadolint \
    && mv hadolint /usr/local/bin/

# Install Kyverno CLI
RUN curl -L https://github.com/kyverno/kyverno/releases/latest/download/kyverno-linux-x86_64.tar.gz | tar xz \
    && mv kyverno /usr/local/bin/

# Install Maven (if not already included)
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

USER jenkins

# Copy Jenkins configuration files
COPY jenkins/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt

# Copy JCasC configuration
COPY jenkins/jenkins.yaml /usr/share/jenkins/ref/jenkins.yaml

# Set environment variables
ENV JAVA_OPTS="-Xmx2g -Xms2g -Djenkins.install.runSetupWizard=false"
ENV JENKINS_OPTS="--prefix=/jenkins"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/jenkins.yaml

EXPOSE 8080 50000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/jenkins/login || exit 1
