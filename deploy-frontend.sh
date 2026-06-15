#!/bin/bash
# ============================================================
# AI Content Guard - Frontend Deploy
# ============================================================
# Builds React app and uploads to Amplify.
# Reads Amplify App ID from SSM and API URL from stack output.
#
# Prerequisites:
#   - Infra deployed via ./deploy.sh (Amplify stack must exist)
#   - Node.js 18+ and npm installed
#
# Usage:
#   ./deploy-frontend.sh
# ============================================================

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-ai-content-guard}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "============================================================"
echo " AI Content Guard - Frontend Deploy"
echo "============================================================"
echo ""

# ─────────────────────────────────────────────
# Step 1: Read config from SSM & stack outputs
# ─────────────────────────────────────────────
echo "→ [1/3] Reading config from SSM..."

AMPLIFY_APP_ID=$(aws ssm get-parameter \
  --name "/${PROJECT_NAME}/amplify/app-id" \
  --region "${AWS_REGION}" \
  --query "Parameter.Value" --output text)

API_URL=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}-api-gateway" \
  --region "${AWS_REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text)

echo "  Amplify App ID: ${AMPLIFY_APP_ID}"
echo "  API URL:        ${API_URL}"
echo ""

# ─────────────────────────────────────────────
# Step 2: Build React app
# ─────────────────────────────────────────────
echo "→ [2/3] Building React app..."

cd frontend
export VITE_API_URL="${API_URL}"
npm install --silent
npm run build
cd ..

echo "  ✓ Build complete"
echo ""

# ─────────────────────────────────────────────
# Step 3: Upload to Amplify
# ─────────────────────────────────────────────
echo "→ [3/3] Uploading to Amplify..."

cd frontend/dist
zip -r ../../frontend-build.zip . -q
cd ../..

DEPLOY_RESULT=$(aws amplify create-deployment \
  --app-id "${AMPLIFY_APP_ID}" \
  --branch-name main \
  --region "${AWS_REGION}" \
  --output json)

JOB_ID=$(echo "${DEPLOY_RESULT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['jobId'])")
UPLOAD_URL=$(echo "${DEPLOY_RESULT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['zipUploadUrl'])")

curl -s -T frontend-build.zip "${UPLOAD_URL}" --header "Content-Type: application/zip"

aws amplify start-deployment \
  --app-id "${AMPLIFY_APP_ID}" \
  --branch-name main \
  --job-id "${JOB_ID}" \
  --region "${AWS_REGION}" > /dev/null

rm frontend-build.zip

echo "  ✓ Deployment started (Job: ${JOB_ID})"
echo ""

# Wait and check status
sleep 10
DEPLOY_STATUS=$(aws amplify get-job \
  --app-id "${AMPLIFY_APP_ID}" \
  --branch-name main \
  --job-id "${JOB_ID}" \
  --region "${AWS_REGION}" \
  --query "job.summary.status" \
  --output text 2>/dev/null || echo "IN_PROGRESS")

AMPLIFY_URL=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT_NAME}-amplify" \
  --region "${AWS_REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='AmplifyAppUrl'].OutputValue" \
  --output text)

echo "============================================================"
echo " ✅ FRONTEND DEPLOYED"
echo "============================================================"
echo ""
echo " Status: ${DEPLOY_STATUS}"
echo " URL:    ${AMPLIFY_URL}"
echo ""
echo "============================================================"
