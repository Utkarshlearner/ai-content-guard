#!/bin/bash
# ============================================================
# AI Content Guard - Stack Deletion Script
# ============================================================
# Deletes all CloudFormation stacks in reverse dependency order:
#   5. API Gateway
#   4. Lambda Function
#   3. IAM Role
#   2. Bedrock Guardrail + SSM Parameters
#   1. DynamoDB Table
#
# Usage:
#   export AWS_REGION=us-east-1           (optional, defaults to us-east-1)
#   export PROJECT_NAME=ai-content-guard  (optional)
#   ./destroy.sh
# ============================================================

set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
PROJECT_NAME="${PROJECT_NAME:-ai-content-guard}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================================"
echo " AI Content Guard - Stack Deletion"
echo "============================================================"
echo " Project: ${PROJECT_NAME}"
echo " Region:  ${AWS_REGION}"
echo "============================================================"
echo ""
echo " ⚠️  This will DELETE all resources permanently!"
echo ""
read -p " Are you sure? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo " Aborted."
  exit 0
fi
echo ""

# ─────────────────────────────────────────────
# Step 1: Delete Amplify (if exists)
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [1/6] Deleting Amplify stack (if exists)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if aws cloudformation describe-stacks --stack-name "${PROJECT_NAME}-amplify" --region "${AWS_REGION}" > /dev/null 2>&1; then
  aws cloudformation delete-stack \
    --stack-name "${PROJECT_NAME}-amplify" \
    --region "${AWS_REGION}"

  aws cloudformation wait stack-delete-complete \
    --stack-name "${PROJECT_NAME}-amplify" \
    --region "${AWS_REGION}"

  echo " ✓ Amplify stack deleted"
else
  echo " ⏭ Amplify stack not found, skipping"
fi
echo ""

# ─────────────────────────────────────────────
# Step 2: Delete API Gateway
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [2/6] Deleting API Gateway stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws cloudformation delete-stack \
  --stack-name "${PROJECT_NAME}-api-gateway" \
  --region "${AWS_REGION}"

aws cloudformation wait stack-delete-complete \
  --stack-name "${PROJECT_NAME}-api-gateway" \
  --region "${AWS_REGION}"

echo " ✓ API Gateway stack deleted"
echo ""

# ─────────────────────────────────────────────
# Step 3: Delete Lambda Function
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [3/6] Deleting Lambda stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws cloudformation delete-stack \
  --stack-name "${PROJECT_NAME}-lambda" \
  --region "${AWS_REGION}"

aws cloudformation wait stack-delete-complete \
  --stack-name "${PROJECT_NAME}-lambda" \
  --region "${AWS_REGION}"

echo " ✓ Lambda stack deleted"
echo ""

# ─────────────────────────────────────────────
# Step 4: Delete IAM Role
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [4/6] Deleting IAM Role stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws cloudformation delete-stack \
  --stack-name "${PROJECT_NAME}-iam-role" \
  --region "${AWS_REGION}"

aws cloudformation wait stack-delete-complete \
  --stack-name "${PROJECT_NAME}-iam-role" \
  --region "${AWS_REGION}"

echo " ✓ IAM Role stack deleted"
echo ""

# ─────────────────────────────────────────────
# Step 5: Delete Bedrock Guardrail + SSM Params
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [5/6] Deleting Guardrail + SSM Parameters stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws cloudformation delete-stack \
  --stack-name "${PROJECT_NAME}-guardrail" \
  --region "${AWS_REGION}"

aws cloudformation wait stack-delete-complete \
  --stack-name "${PROJECT_NAME}-guardrail" \
  --region "${AWS_REGION}"

echo " ✓ Guardrail stack deleted"
echo ""

# ─────────────────────────────────────────────
# Step 6: Delete DynamoDB Table
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [6/6] Deleting DynamoDB stack..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

aws cloudformation delete-stack \
  --stack-name "${PROJECT_NAME}-dynamodb" \
  --region "${AWS_REGION}"

aws cloudformation wait stack-delete-complete \
  --stack-name "${PROJECT_NAME}-dynamodb" \
  --region "${AWS_REGION}"

echo " ✓ DynamoDB stack deleted"
echo ""

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "============================================================"
echo " ✅ ALL STACKS DELETED"
echo "============================================================"
echo ""
echo " Deleted stacks:"
echo "   1. ${PROJECT_NAME}-amplify (if existed)"
echo "   2. ${PROJECT_NAME}-api-gateway"
echo "   3. ${PROJECT_NAME}-lambda"
echo "   4. ${PROJECT_NAME}-iam-role"
echo "   5. ${PROJECT_NAME}-guardrail"
echo "   6. ${PROJECT_NAME}-dynamodb"
echo ""
echo " All resources have been removed."
echo "============================================================"
