#!/bin/bash
set -e

echo "========================================="
echo "Stage 1: EKS Cluster Platform Check"
echo "========================================="

# Check if cluster exists and is active
echo "Checking EKS cluster: $EKS_CLUSTER_NAME"
CLUSTER_STATUS=$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" --query 'cluster.status' --output text)

if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "❌ ERROR: EKS cluster is not ACTIVE. Current status: $CLUSTER_STATUS"
    exit 1
fi

echo "✅ EKS cluster is ACTIVE"

# Check node groups
echo ""
echo "Checking node groups..."
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" --query 'nodegroups' --output json)

if [ "$NODE_GROUPS" == "[]" ]; then
    echo "❌ ERROR: No node groups found"
    exit 1
fi

echo "Found node groups: $NODE_GROUPS"

# Check worker nodes status
echo ""
echo "Checking worker nodes status..."
NODES=$(kubectl get nodes --no-headers 2>/dev/null || echo "")

if [ -z "$NODES" ]; then
    echo "❌ ERROR: No worker nodes found or kubectl not configured"
    exit 1
fi

echo "Worker Nodes:"
kubectl get nodes

# Check if all nodes are Ready
NOT_READY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)

if [ "$NOT_READY" -gt 0 ]; then
    echo "❌ ERROR: Some worker nodes are not in Ready state"
    kubectl get nodes | grep -v " Ready "
    exit 1
fi

echo "✅ All worker nodes are in Ready state"

# Check critical system pods
echo ""
echo "Checking critical system pods..."
SYSTEM_PODS_NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" | wc -l)

if [ "$SYSTEM_PODS_NOT_RUNNING" -gt 0 ]; then
    echo "⚠️  WARNING: Some system pods are not running"
    kubectl get pods -n kube-system | grep -v "Running\|Completed"
else
    echo "✅ All system pods are running"
fi

echo ""
echo "========================================="
echo "✅ Platform check completed successfully"
echo "========================================="
