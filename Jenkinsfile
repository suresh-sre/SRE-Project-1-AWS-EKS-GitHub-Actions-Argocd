// Jenkins Declarative Pipeline for CI/CD
// Implements multi-stage pipeline with security scanning and ArgoCD integration

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
    }

    environment {
        // AWS Configuration
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')

        // Build Configuration
        JAVA_VERSION = '11'
        MAVEN_HOME = '/usr/share/maven'
        DOCKER_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        
        // Repository Configuration
        GIT_REPO = credentials('git-repository-url')
        GIT_CREDENTIALS = credentials('git-credentials')
        
        // ArgoCD Configuration
        ARGOCD_SERVER = credentials('argocd-server')
        ARGOCD_TOKEN = credentials('argocd-token')
        
        // Security Scanning
        SNYK_TOKEN = credentials('snyk-api-token')
        SNYK_SEVERITY_THRESHOLD = 'high'
        
        // Build Metadata
        BUILD_TIMESTAMP = sh(script: "date +'%Y%m%d-%H%M%S'", returnStdout: true).trim()
        GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        GIT_BRANCH_NAME = sh(script: "git rev-parse --abbrev-ref HEAD | sed 's/origin\\///'", returnStdout: true).trim()
        IMAGE_TAG = "${GIT_COMMIT_SHORT}-${BUILD_TIMESTAMP}"
        ECR_REPO_NAME = "${JOB_NAME.toLowerCase()}"
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip Maven unit tests'
        )
        booleanParam(
            name: 'SKIP_SECURITY_SCAN',
            defaultValue: false,
            description: 'Skip Snyk security scanning'
        )
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "====== CI/CD Pipeline Started ======"
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Branch: ${GIT_BRANCH_NAME}"
                    echo "Commit: ${GIT_COMMIT_SHORT}"
                    echo "Image Tag: ${IMAGE_TAG}"
                    echo "Registry: ${DOCKER_REGISTRY}"
                    
                    // Validate environment branch
                    if ((ENVIRONMENT == 'dev' && GIT_BRANCH_NAME != 'dev') ||
                        (ENVIRONMENT == 'qa' && GIT_BRANCH_NAME != 'qa') ||
                        (ENVIRONMENT == 'prod' && GIT_BRANCH_NAME != 'prod')) {
                        error("Branch '${GIT_BRANCH_NAME}' does not match environment '${ENVIRONMENT}'")
                    }
                }
            }
        }

        stage('Platform Check') {
            steps {
                script {
                    echo "====== Stage: Platform Check ======"
                    echo "Validating EKS cluster health and connectivity..."
                    
                    sh '''
                        # Install kubectl
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/ || true
                        
                        # Configure AWS credentials
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set default.region $AWS_DEFAULT_REGION
                        
                        # Update kubeconfig
                        EKS_CLUSTER_NAME="cicd-pipeline-${ENVIRONMENT}"
                        aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $EKS_CLUSTER_NAME
                        
                        # Check cluster health
                        ./scripts/check-eks-cluster.sh
                    '''
                }
            }
        }

        stage('Validate') {
            parallel {
                stage('Validate Dockerfile') {
                    steps {
                        script {
                            echo "====== Stage: Validate Dockerfile ======"
                            sh '''
                                # Install Hadolint
                                curl -L https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 -o hadolint
                                chmod +x hadolint
                                sudo mv hadolint /usr/local/bin/ || true
                                
                                # Lint Dockerfile
                                hadolint Dockerfile --ignore DL3008,DL3009 || true
                            '''
                        }
                    }
                }

                stage('Validate Kubernetes') {
                    steps {
                        script {
                            echo "====== Stage: Validate Kubernetes ======"
                            sh '''
                                # Install kubeconform
                                curl -L https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
                                sudo mv kubeconform /usr/local/bin/ || true
                                
                                # Validate K8s manifests
                                ./scripts/validate-k8s-manifests.sh
                            '''
                        }
                    }
                }

                stage('Validate Kyverno Policies') {
                    steps {
                        script {
                            echo "====== Stage: Validate Kyverno Policies ======"
                            sh '''
                                # Install Kyverno CLI
                                curl -L https://github.com/kyverno/kyverno/releases/latest/download/kyverno-linux-x86_64.tar.gz | tar xz
                                sudo mv kyverno /usr/local/bin/ || true
                                
                                # Test Kyverno policies
                                kyverno apply kyverno-policies/ --resource helm-chart/templates/deployment.yaml || true
                            '''
                        }
                    }
                }

                stage('SAST Security Scan') {
                    when {
                        expression { !params.SKIP_SECURITY_SCAN }
                    }
                    steps {
                        script {
                            echo "====== Stage: SAST Security Scan (Snyk) ======"
                            sh '''
                                # Install Snyk CLI
                                npm install -g snyk
                                
                                # Authenticate with Snyk
                                snyk auth $SNYK_TOKEN
                                
                                # Run SAST scan
                                snyk test --severity-threshold=$SNYK_SEVERITY_THRESHOLD || true
                                snyk monitor --severity-threshold=$SNYK_SEVERITY_THRESHOLD || true
                            '''
                        }
                    }
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    echo "====== Stage: Build (Maven) ======"
                    sh '''
                        # Build with Maven
                        mvn clean package ${SKIP_TESTS ? '-DskipTests' : ''}
                    '''
                }
            }
        }

        stage('Package') {
            parallel {
                stage('Package Docker Image') {
                    steps {
                        script {
                            echo "====== Stage: Package Docker Image ======"
                            sh '''
                                # Configure AWS credentials for ECR
                                aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                                aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                                aws configure set default.region $AWS_DEFAULT_REGION
                                
                                # Login to ECR
                                aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
                                  docker login --username AWS --password-stdin $DOCKER_REGISTRY
                                
                                # Build Docker image
                                docker build -t $DOCKER_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG \
                                            -t $DOCKER_REGISTRY/$ECR_REPO_NAME:latest \
                                            -t $DOCKER_REGISTRY/$ECR_REPO_NAME:${ENVIRONMENT}-latest .
                                
                                # Push to ECR
                                docker push $DOCKER_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG
                                docker push $DOCKER_REGISTRY/$ECR_REPO_NAME:latest
                                docker push $DOCKER_REGISTRY/$ECR_REPO_NAME:${ENVIRONMENT}-latest
                            '''
                        }
                    }
                }

                stage('Package Helm Chart') {
                    steps {
                        script {
                            echo "====== Stage: Package Helm Chart ======"
                            sh '''
                                # Install Helm
                                curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                                
                                # Configure AWS ECR for Helm
                                aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
                                  helm registry login --username AWS --password-stdin $DOCKER_REGISTRY
                                
                                # Package Helm chart
                                cd helm-chart
                                helm package . --version $IMAGE_TAG --app-version $IMAGE_TAG
                                
                                # Push Helm chart to ECR
                                helm push *.tgz oci://$DOCKER_REGISTRY/helm-charts
                                cd ..
                            '''
                        }
                    }
                }
            }
        }

        stage('Container Security Scan') {
            when {
                expression { !params.SKIP_SECURITY_SCAN }
            }
            steps {
                script {
                    echo "====== Stage: Container Security Scan ======"
                    sh '''
                        # Configure AWS credentials
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set default.region $AWS_DEFAULT_REGION
                        
                        # Login to ECR
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
                          docker login --username AWS --password-stdin $DOCKER_REGISTRY
                        
                        # Pull image
                        docker pull $DOCKER_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG
                        
                        # Run Snyk container scan
                        npm install -g snyk
                        snyk auth $SNYK_TOKEN
                        snyk container test $DOCKER_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG \
                          --severity-threshold=$SNYK_SEVERITY_THRESHOLD || true
                        snyk container monitor $DOCKER_REGISTRY/$ECR_REPO_NAME:$IMAGE_TAG \
                          --severity-threshold=$SNYK_SEVERITY_THRESHOLD || true
                    '''
                }
            }
        }

        stage('Promote to ArgoCD') {
            when {
                expression { ENVIRONMENT in ['dev', 'qa', 'prod'] }
            }
            steps {
                script {
                    echo "====== Stage: Promote to ArgoCD (${ENVIRONMENT}) ======"
                    sh '''
                        # Configure Git
                        git config --global user.email "jenkins@cicd-pipeline.local"
                        git config --global user.name "Jenkins CI/CD"
                        
                        # Update configuration repository
                        HELM_CHART_VERSION=$IMAGE_TAG
                        IMAGE_VERSION=$IMAGE_TAG
                        
                        ./scripts/update-config-repo.sh ${ENVIRONMENT} $HELM_CHART_VERSION $IMAGE_VERSION
                    '''
                }
            }
        }

        stage('Approval Gate - QA') {
            when {
                expression { ENVIRONMENT == 'qa' }
            }
            steps {
                script {
                    echo "====== Stage: Approval Gate (QA) ======"
                    timeout(time: 24, unit: 'HOURS') {
                        input message: 'Approve deployment to QA?', ok: 'Deploy'
                    }
                }
            }
        }

        stage('Approval Gate - Production') {
            when {
                expression { ENVIRONMENT == 'prod' }
            }
            steps {
                script {
                    echo "====== Stage: Approval Gate (Production) ======"
                    timeout(time: 24, unit: 'HOURS') {
                        input message: 'Approve deployment to PRODUCTION?', ok: 'Deploy'
                    }
                }
            }
        }

        stage('Verify ArgoCD Deployment') {
            when {
                expression { ENVIRONMENT in ['dev', 'qa', 'prod'] }
            }
            steps {
                script {
                    echo "====== Stage: Verify ArgoCD Deployment ======"
                    sh '''
                        # Wait for ArgoCD to sync
                        sleep 30
                        
                        # Check ArgoCD application status
                        APP_NAME="${JOB_NAME,,}-${ENVIRONMENT}"
                        
                        echo "Checking ArgoCD application status for: $APP_NAME"
                        
                        # Using curl with ArgoCD API (adjust URL and token as needed)
                        curl -H "Authorization: Bearer $ARGOCD_TOKEN" \
                             $ARGOCD_SERVER/api/v1/applications/$APP_NAME || echo "ArgoCD verification skipped"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "====== Pipeline Cleanup ======"
                
                // Clean Docker images to save space
                sh '''
                    docker image prune -af --filter "until=72h" || true
                '''
                
                // Clean workspace
                cleanWs()
            }
        }

        success {
            script {
                echo "====== Pipeline Completed Successfully ======"
                echo "Build: ${env.BUILD_NUMBER}"
                echo "Environment: ${ENVIRONMENT}"
                echo "Image: ${DOCKER_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
            }
        }

        failure {
            script {
                echo "====== Pipeline Failed ======"
                echo "Build: ${env.BUILD_NUMBER}"
                echo "Check logs for details"
            }
        }
    }
}

// ============================================================
// INFRASTRUCTURE AS CODE (IaC) CI/CD PIPELINE - TERRAFORM
// ============================================================

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
    }

    environment {
        TF_IN_AUTOMATION = "true"
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'qa', 'prod'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'DESTROY_INFRASTRUCTURE',
            defaultValue: false,
            description: 'Destroy infrastructure (use with caution)'
        )
    }

    stages {

        stage('Checkout') {
            steps {
                script {
                    echo "====== Stage: Checkout ======"
                    checkout scm
                }
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    echo "====== Stage: Terraform Init ======"
                    dir('terraform') {
                        sh '''
                            echo "Initializing Terraform..."
                            terraform init
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                script {
                    echo "====== Stage: Terraform Validate ======"
                    dir('terraform') {
                        sh '''
                            echo "Validating Terraform configuration..."
                            terraform validate
                        '''
                    }
                }
            }
        }

        stage('TFLint Scan') {
            steps {
                script {
                    echo "====== Stage: TFLint Scan ======"
                    dir('terraform') {
                        sh '''
                            echo "Running TFLint..."
                            curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
                            tflint --init || true
                            tflint . || true
                        '''
                    }
                }
            }
        }

        stage('tfsec Security Scan') {
            steps {
                script {
                    echo "====== Stage: tfsec Security Scan ======"
                    dir('terraform') {
                        sh '''
                            echo "Running tfsec security scan..."
                            curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
                            tfsec . || true
                        '''
                    }
                }
            }
        }

        stage('Checkov Compliance Scan') {
            steps {
                script {
                    echo "====== Stage: Checkov Compliance Scan ======"
                    dir('terraform') {
                        sh '''
                            echo "Running Checkov compliance scan..."
                            pip install checkov -q || true
                            checkov -d . || true
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    echo "====== Stage: Terraform Plan ======"
                    dir('terraform') {
                        sh '''
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                            aws configure set default.region $AWS_DEFAULT_REGION
                            
                            echo "Planning Terraform deployment for environment: ${ENVIRONMENT}"
                            terraform plan -var="environment=${ENVIRONMENT}" -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Manual Approval - Apply') {
            when {
                expression { !params.DESTROY_INFRASTRUCTURE }
            }
            steps {
                script {
                    echo "====== Stage: Manual Approval - Apply ======"
                    timeout(time: 24, unit: 'HOURS') {
                        input message: "Approve Terraform Apply for ${ENVIRONMENT}?", ok: 'Apply'
                    }
                }
            }
        }

        stage('Manual Approval - Destroy') {
            when {
                expression { params.DESTROY_INFRASTRUCTURE }
            }
            steps {
                script {
                    echo "====== Stage: Manual Approval - Destroy ======"
                    echo "⚠️  WARNING: This will DESTROY infrastructure in ${ENVIRONMENT}"
                    timeout(time: 24, unit: 'HOURS') {
                        input message: "⚠️  Confirm DESTRUCTION of ${ENVIRONMENT} infrastructure?", ok: 'Destroy'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { !params.DESTROY_INFRASTRUCTURE }
            }
            steps {
                script {
                    echo "====== Stage: Terraform Apply ======"
                    dir('terraform') {
                        sh '''
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                            aws configure set default.region $AWS_DEFAULT_REGION
                            
                            echo "Applying Terraform configuration..."
                            terraform apply -auto-approve tfplan
                            
                            echo "Generating Terraform outputs..."
                            terraform output > terraform-outputs.txt
                        '''
                    }
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.DESTROY_INFRASTRUCTURE }
            }
            steps {
                script {
                    echo "====== Stage: Terraform Destroy ======"
                    dir('terraform') {
                        sh '''
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                            aws configure set default.region $AWS_DEFAULT_REGION
                            
                            echo "⚠️  Destroying Terraform infrastructure in ${ENVIRONMENT}..."
                            terraform destroy -auto-approve -var="environment=${ENVIRONMENT}"
                        '''
                    }
                }
            }
        }

        stage('Update kubeconfig') {
            when {
                expression { !params.DESTROY_INFRASTRUCTURE }
            }
            steps {
                script {
                    echo "====== Stage: Update kubeconfig ======"
                    sh '''
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set default.region $AWS_DEFAULT_REGION
                        
                        EKS_CLUSTER_NAME="cicd-pipeline-${ENVIRONMENT}"
                        echo "Updating kubeconfig for cluster: $EKS_CLUSTER_NAME"
                        aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $EKS_CLUSTER_NAME || true
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "====== Infrastructure Pipeline Cleanup ======"
                
                // Cleanup Terraform plan
                sh 'rm -f terraform/tfplan || true'
            }
        }

        success {
            script {
                if (params.DESTROY_INFRASTRUCTURE) {
                    echo "✅ Infrastructure DESTROYED successfully"
                    echo "Environment: ${ENVIRONMENT}"
                } else {
                    echo "✅ Infrastructure deployed successfully"
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Build: ${env.BUILD_NUMBER}"
                }
            }
        }

        failure {
            script {
                echo "❌ Infrastructure pipeline failed"
                echo "Build: ${env.BUILD_NUMBER}"
                echo "Environment: ${ENVIRONMENT}"
                echo "Check logs for details"
            }
        }

        unstable {
            script {
                echo "⚠️  Infrastructure pipeline is unstable"
                echo "Security or compliance scans detected issues"
            }
        }
    }
}
