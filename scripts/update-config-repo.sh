#!/bin/bash
set -e

ENVIRONMENT=$1
HELM_CHART_VERSION=$2
IMAGE_TAG=$3

if [ -z "$ENVIRONMENT" ] || [ -z "$HELM_CHART_VERSION" ] || [ -z "$IMAGE_TAG" ]; then
    echo "Usage: $0 <environment> <helm_chart_version> <image_tag>"
    exit 1
fi

echo "========================================="
echo "Stage 6: Updating Config Repository"
echo "========================================="
echo "Environment: $ENVIRONMENT"
echo "Helm Chart Version: $HELM_CHART_VERSION"
echo "Image Tag: $IMAGE_TAG"
echo "========================================="

# Construct AWS_ECR_REGISTRY and PROJECT_NAME
AWS_ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
PROJECT_NAME=$(basename "${GITHUB_REPOSITORY:-SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd}")

echo "Updating config for project: $PROJECT_NAME in $AWS_ECR_REGISTRY"

# Update the helm values file for the environment
CONFIG_FILE="helm-chart/values-${ENVIRONMENT}.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Values file $CONFIG_FILE does not exist!"
    exit 1
fi

# Determine correct ECR repository name (matching Terraform)
ECR_REPO_NAME="cicd-pipeline-${ENVIRONMENT}-app-backend"

# Update image repository and tag
sed -i "s|repository: .*|repository: ${AWS_ECR_REGISTRY}/${ECR_REPO_NAME}|g" $CONFIG_FILE
sed -i "s|tag: .*|tag: ${IMAGE_TAG}|g" $CONFIG_FILE

echo "✅ Updated values file: $CONFIG_FILE"
cat $CONFIG_FILE

# Commit and push changes
echo ""
echo "Committing changes to config repository..."
git add $CONFIG_FILE

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "No changes to commit."
else
    git commit -m "Update ${ENVIRONMENT} config - Helm: ${HELM_CHART_VERSION}, Image: ${IMAGE_TAG}

Triggered by: ${GITHUB_ACTOR}
Pipeline: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}
Commit: ${GITHUB_SHA}"

    git push origin HEAD:${GITHUB_REF_NAME}
fi

echo ""
echo "========================================="
echo "✅ Config repository updated successfully"
echo "ArgoCD will detect changes and deploy to ${ENVIRONMENT}"
echo "========================================="
