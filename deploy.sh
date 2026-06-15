#!/bin/bash
# ============================================================
# AI Content Guard - Deployment Script
# ============================================================
# Deploy all infra or a specific step.
#
# Usage:
#   ./deploy.sh              # Asks what to deploy
#   ./deploy.sh all          # Deploy all steps (1-6)
#   ./deploy.sh dynamodb     # Deploy only DynamoDB
#   ./deploy.sh guardrail    # Deploy only Guardrail + SSM
#   ./deploy.sh iam          # Deploy only IAM Role
#   ./deploy.sh lambda       # Deploy only Lambda
#   ./deploy.sh api          # Deploy only API Gateway
#   ./deploy.sh amplify      # Deploy only Amplify
#
# Environment Variables (optional):
#   AWS_REGION=us-east-1
#   PROJECT_NAME=ai-content-guard
#   STAGE_NAME=prod
#   ENVIRONMENT=production
#   OWNER=utkarsh
# ============================================================

set -euo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
PROJECT_NAME="${PROJECT_NAME:-ai-content-guard}"
AWS_REGION="${AWS_REGION:-us-east-1}"
STAGE_NAME="${STAGE_NAME:-prod}"
ENVIRONMENT="${ENVIRONMENT:-production}"
OWNER="${OWNER:-utkarsh}"
STEP="${1:-}"

# If no step provided, ask the user
if [[ -z "${STEP}" ]]; then
  echo "What would you like to deploy?"
  echo ""
  echo "  all        - Deploy all infra (steps 1-6)"
  echo "  dynamodb   - DynamoDB table"
  echo "  guardrail  - Bedrock Guardrail + SSM"
  echo "  iam        - IAM Role"
  echo "  lambda     - Lambda function"
  echo "  api        - API Gateway"
  echo "  amplify    - Amplify app"
  echo ""
  read -p "Enter step: " STEP
  echo ""
fi

TAGS=(
  "Project=${PROJECT_NAME}"
  "Environment=${ENVIRONMENT}"
  "Owner=${OWNER}"
  "ManagedBy=CloudFormation"
  "Application=AI-Content-Guard"
)

echo "============================================================"
echo " AI Content Guard - Deploy [${STEP}]"
echo "============================================================"
echo " Project: ${PROJECT_NAME} | Region: ${AWS_REGION} | Env: ${ENVIRONMENT}"
echo "============================================================"
echo ""

# ─────────────────────────────────────────────
# Helper: get stack output
# ─────────────────────────────────────────────
get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$1" \
    --region "${AWS_REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" \
    --output text
}

# ─────────────────────────────────────────────
# Step 1: DynamoDB
# ─────────────────────────────────────────────
deploy_dynamodb() {
  echo "→ [1/6] Deploying DynamoDB..."
  aws cloudformation deploy \
    --template-file infra/dynamodb.yaml \
    --stack-name "${PROJECT_NAME}-dynamodb" \
    --parameter-overrides ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ DynamoDB: $(get_output ${PROJECT_NAME}-dynamodb SummaryTableName)"
  echo ""
}

# ─────────────────────────────────────────────
# Step 2: Guardrail + SSM
# ─────────────────────────────────────────────
deploy_guardrail() {
  echo "→ [2/6] Deploying Bedrock Guardrail + SSM..."
  aws cloudformation deploy \
    --template-file infra/guardrail.yaml \
    --stack-name "${PROJECT_NAME}-guardrail" \
    --parameter-overrides ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ Guardrail: $(get_output ${PROJECT_NAME}-guardrail GuardrailId) (v$(get_output ${PROJECT_NAME}-guardrail GuardrailVersion))"
  echo ""
}

# ─────────────────────────────────────────────
# Step 3: IAM Role
# ─────────────────────────────────────────────
deploy_iam() {
  echo "→ [3/6] Deploying IAM Role..."
  local TABLE_ARN=$(get_output "${PROJECT_NAME}-dynamodb" SummaryTableArn)
  local GUARDRAIL_ARN=$(get_output "${PROJECT_NAME}-guardrail" GuardrailArn)

  aws cloudformation deploy \
    --template-file infra/iam-role.yaml \
    --stack-name "${PROJECT_NAME}-iam-role" \
    --parameter-overrides \
      ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
      DynamoDBTableArn="${TABLE_ARN}" BedrockGuardrailArn="${GUARDRAIL_ARN}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ IAM Role: $(get_output ${PROJECT_NAME}-iam-role LambdaExecutionRoleArn)"
  echo ""
}

# ─────────────────────────────────────────────
# Step 4: Lambda
# ─────────────────────────────────────────────
deploy_lambda() {
  echo "→ [4/6] Deploying Lambda..."
  local ROLE_ARN=$(get_output "${PROJECT_NAME}-iam-role" LambdaExecutionRoleArn)
  local TABLE_NAME=$(get_output "${PROJECT_NAME}-dynamodb" SummaryTableName)

  aws cloudformation deploy \
    --template-file infra/lambda.yaml \
    --stack-name "${PROJECT_NAME}-lambda" \
    --parameter-overrides \
      ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
      LambdaRoleArn="${ROLE_ARN}" DynamoDBTableName="${TABLE_NAME}" \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ Lambda: $(get_output ${PROJECT_NAME}-lambda SummarizerFunctionName)"
  echo ""
}

# ─────────────────────────────────────────────
# Step 5: API Gateway
# ─────────────────────────────────────────────
deploy_api() {
  echo "→ [5/6] Deploying API Gateway..."
  local LAMBDA_ARN=$(get_output "${PROJECT_NAME}-lambda" SummarizerFunctionArn)

  aws cloudformation deploy \
    --template-file infra/api-gateway.yaml \
    --stack-name "${PROJECT_NAME}-api-gateway" \
    --parameter-overrides \
      ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
      LambdaFunctionArn="${LAMBDA_ARN}" StageName="${STAGE_NAME}" \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ API: $(get_output ${PROJECT_NAME}-api-gateway ApiUrl)"
  echo ""
}

# ─────────────────────────────────────────────
# Step 6: Amplify
# ─────────────────────────────────────────────
deploy_amplify() {
  echo "→ [6/6] Deploying Amplify..."
  local API_URL=$(get_output "${PROJECT_NAME}-api-gateway" ApiUrl)

  aws cloudformation deploy \
    --template-file infra/amplify.yaml \
    --stack-name "${PROJECT_NAME}-amplify" \
    --parameter-overrides \
      ProjectName="${PROJECT_NAME}" Environment="${ENVIRONMENT}" Owner="${OWNER}" \
      ApiUrl="${API_URL}" \
    --tags "${TAGS[@]}" \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset
  echo "  ✓ Amplify: $(get_output ${PROJECT_NAME}-amplify AmplifyAppUrl)"
  echo ""
}

# ─────────────────────────────────────────────
# Execute
# ─────────────────────────────────────────────
case "${STEP}" in
  all)
    deploy_dynamodb
    deploy_guardrail
    deploy_iam
    deploy_lambda
    deploy_api
    deploy_amplify
    echo "============================================================"
    echo " ✅ ALL STACKS DEPLOYED"
    echo "============================================================"
    echo ""
    echo " Now deploy the frontend:"
    echo "   ./deploy-frontend.sh"
    ;;
  dynamodb)   deploy_dynamodb ;;
  guardrail)  deploy_guardrail ;;
  iam)        deploy_iam ;;
  lambda)     deploy_lambda ;;
  api)        deploy_api ;;
  amplify)    deploy_amplify ;;
  *)
    echo "Unknown step: ${STEP}"
    echo ""
    echo "Usage: ./deploy.sh [step]"
    echo ""
    echo "Steps:"
    echo "  all        Deploy all infra (default)"
    echo "  dynamodb   DynamoDB table"
    echo "  guardrail  Bedrock Guardrail + SSM"
    echo "  iam        IAM Role"
    echo "  lambda     Lambda function"
    echo "  api        API Gateway"
    echo "  amplify    Amplify app"
    exit 1
    ;;
esac
