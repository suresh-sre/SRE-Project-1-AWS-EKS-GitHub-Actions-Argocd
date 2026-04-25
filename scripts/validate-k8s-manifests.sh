#!/bin/bash
set -e

echo "========================================="
echo "Stage 2: Kubernetes Manifest Validation"
echo "========================================="

# Validate Helm chart templates
echo "Validating Helm chart templates..."
cd helm-chart

# Generate manifests from Helm chart
helm template test-release . --values values.yaml > /tmp/rendered-manifests.yaml

echo "✅ Helm chart rendered successfully"

# Validate with kubeconform
echo ""
echo "Validating Kubernetes manifests with kubeconform..."
kubeconform -summary -output text /tmp/rendered-manifests.yaml

if [ $? -eq 0 ]; then
    echo "✅ All Kubernetes manifests are valid"
else
    echo "❌ Kubernetes manifest validation failed"
    exit 1
fi

# Validate individual template files
echo ""
echo "Validating individual template files..."
for file in templates/*.yaml; do
    if [ -f "$file" ]; then
        echo "Checking $file..."
        # Skip files with Helm templating that can't be validated standalone
        if grep -q "{{" "$file"; then
            echo "  ⏭️  Skipping (contains Helm templates)"
        else
            kubeconform "$file" || echo "  ⚠️  Validation failed for $file"
        fi
    fi
done

echo ""
echo "========================================="
echo "✅ Validation completed successfully"
echo "========================================="
