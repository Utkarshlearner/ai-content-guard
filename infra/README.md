# AI Content Guard - Infrastructure

CloudFormation templates for the AI Content Guard backend. Each AWS resource is defined in its own template and deployed as a separate stack.

## Templates

| File | Stack Name | Resources |
|------|-----------|-----------|
| `dynamodb.yaml` | `ai-content-guard-dynamodb` | DynamoDB table (PAY_PER_REQUEST, SSE, PITR, TTL) |
| `guardrail.yaml` | `ai-content-guard-guardrail` | Bedrock Guardrail + 3 SSM Parameters |
| `iam-role.yaml` | `ai-content-guard-iam-role` | Lambda execution role (least-privilege) |
| `lambda.yaml` | `ai-content-guard-lambda` | Lambda function (inline Python 3.12) + Log Group |
| `api-gateway.yaml` | `ai-content-guard-api-gateway` | REST API, POST /summarize, CORS, throttling |
| `amplify.yaml` | `ai-content-guard-amplify` | Amplify Hosting app + SSM Parameter |

## Deployment Order

Stacks must be deployed in this order (dependencies flow downward):

```
1. dynamodb       (no dependencies)
2. guardrail      (no dependencies)
3. iam-role       (depends on: dynamodb ARN, guardrail ARN)
4. lambda         (depends on: iam-role ARN, dynamodb name)
5. api-gateway    (depends on: lambda ARN)
6. amplify        (depends on: api-gateway URL)
```

## Parameters

All templates share these common parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ProjectName` | ai-content-guard | Prefix for resource names |
| `Environment` | production | production / staging / development |
| `Owner` | utkarsh | Owner tag value |

Stack-specific parameters are passed automatically by `deploy.sh`.

## SSM Parameters Created

| Path | Created By | Used By |
|------|-----------|---------|
| `/ai-content-guard/guardrail/id` | guardrail.yaml | Lambda (runtime) |
| `/ai-content-guard/guardrail/version` | guardrail.yaml | Lambda (runtime) |
| `/ai-content-guard/guardrail/arn` | guardrail.yaml | Reference only |
| `/ai-content-guard/amplify/app-id` | amplify.yaml | deploy-frontend.sh |

## Lambda Function

The Lambda code is embedded inline in `lambda.yaml` using `Code.ZipFile`. No S3 bucket needed.

**Runtime:** Python 3.12  
**Model:** Amazon Nova Lite (`amazon.nova-lite-v1:0`)  
**Timeout:** 60s  
**Memory:** 256 MB

**Flow:**
1. Validate input (max 10,000 chars)
2. Load guardrail config from SSM (cached per cold start)
3. Apply Bedrock Guardrail on input
   - If all violations are ANONYMIZE → use cleaned text, continue
   - If any violation is BLOCK → reject request (422)
4. Invoke Nova Lite for summarization
5. Apply Bedrock Guardrail on output
   - If all violations are ANONYMIZE → return cleaned summary
   - If any violation is BLOCK → reject request (422)
6. Log to DynamoDB (30-day TTL)

## IAM Permissions (Lambda Role)

| Policy | Access |
|--------|--------|
| AWSLambdaBasicExecutionRole | CloudWatch Logs |
| dynamodb-policy | PutItem, GetItem, Query on table |
| bedrock-policy | InvokeModel (foundation models + inference profiles), ApplyGuardrail |
| ssm-policy | GetParameter, GetParameters on `/ai-content-guard/guardrail/*` |

## Guardrail Configuration

**Content Filters (all HIGH strength):**
- Sexual, Violence, Hate, Insults, Misconduct, Prompt Attack

**PII Handling:**
- Anonymize: Email, Phone, Name (masked as `{EMAIL}`, `{PHONE}`, `{NAME}` — request continues)
- Block: US SSN, Credit/Debit Card Number (request fully rejected)

## Deploy

```bash
# From project root
./deploy.sh all        # All stacks
./deploy.sh lambda     # Just Lambda
./deploy.sh guardrail  # Just Guardrail
```

## Destroy

```bash
./destroy.sh
```

Deletes all stacks in reverse order with confirmation prompt.
