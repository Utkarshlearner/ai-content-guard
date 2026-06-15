# AI Content Guard

AI-powered text summarizer with content safety guardrails. Built on AWS serverless — Lambda, Bedrock, Guardrails, DynamoDB, API Gateway & Amplify. Blocks harmful, abusive, and PII content while delivering clean summaries.

## Architecture

```
┌──────────────┐       ┌─────────────────┐       ┌──────────────────┐
│   React UI   │──────▶│  API Gateway    │──────▶│  Lambda Function │
│  (Amplify)   │◀──────│  POST /summarize│◀──────│  (Python 3.12)   │
└──────────────┘       └─────────────────┘       └────────┬─────────┘
                                                          │
                              ┌────────────────────────────┼────────────────────┐
                              │                            │                    │
                    ┌─────────▼──────────┐    ┌───────────▼───────┐   ┌────────▼────────┐
                    │  Bedrock Guardrail  │    │   Bedrock Model   │   │    DynamoDB     │
                    │  (Content Safety)   │    │  (Nova Lite)      │   │  (Request Logs) │
                    └────────────────────┘    └───────────────────┘   └─────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  SSM Parameter Store│
                    │  (Guardrail Config) │
                    └────────────────────┘
```

## Project Structure

```
ai-content-guard/
├── infra/                       # CloudFormation templates (one per resource)
│   ├── dynamodb.yaml            # DynamoDB table (PAY_PER_REQUEST, SSE, PITR)
│   ├── guardrail.yaml           # Bedrock Guardrail + SSM Parameters
│   ├── iam-role.yaml            # Lambda IAM role (least-privilege)
│   ├── lambda.yaml              # Lambda function (inline Python code)
│   ├── api-gateway.yaml         # REST API with CORS & throttling
│   ├── amplify.yaml             # Amplify Hosting for React frontend
│   └── README.md                # Infra-specific docs
├── frontend/                    # React UI (Vite + React 19)
│   ├── src/
│   │   ├── App.jsx              # Main component
│   │   ├── App.css              # Styles
│   │   ├── main.jsx             # Entry point
│   │   └── index.css            # Global styles
│   ├── index.html
│   ├── .env.example             # API URL template
│   ├── package.json
│   └── README.md                # Frontend-specific docs
├── docs/                        # Documentation & diagrams
│   ├── ARCHITECTURE.md          # Full system design document
│   ├── architecture-diagram.drawio  # Editable architecture diagram
│   ├── ai-content-guard-architecture.png  # Exported diagram
│   ├── presentation-guide.md    # PPT guide (10 slides, 60 min)
│   └── sample-prompts.txt       # Test prompts for demo
├── deploy.sh                    # Infra deployment (interactive)
├── deploy-frontend.sh           # Frontend build & upload to Amplify
├── destroy.sh                   # Tear down all stacks
├── .gitignore
├── LICENSE
└── README.md
```

## Prerequisites

1. **AWS CLI v2** configured with credentials
   ```bash
   aws sts get-caller-identity
   ```

2. **Node.js 18+** and npm (for frontend)
   ```bash
   node --version
   ```

3. **Amazon Bedrock Model Access** — Enable `Amazon Nova Lite` in your region
   - AWS Console → Bedrock → Model access → Request access

4. **IAM Permissions** for the deploying user:
   - `cloudformation:*`, `iam:*`, `lambda:*`, `apigateway:*`
   - `dynamodb:*`, `bedrock:*`, `ssm:*`, `logs:*`, `amplify:*`

## Deployment

### Step 1: Deploy Infrastructure

```bash
./deploy.sh          # Interactive — asks what to deploy
./deploy.sh all      # Deploy all 6 stacks
```

Available steps: `dynamodb`, `guardrail`, `iam`, `lambda`, `api`, `amplify`

### Step 2: Deploy Frontend

```bash
./deploy-frontend.sh
```

Builds the React app and uploads to Amplify. Outputs the live URL.

### Redeploy Individual Components

```bash
./deploy.sh lambda      # After changing Lambda code
./deploy.sh api         # After changing API Gateway config
./deploy-frontend.sh    # After changing frontend code
```

## Stacks Created

| # | Stack Name | Template | Resources |
|---|-----------|----------|-----------|
| 1 | `ai-content-guard-dynamodb` | `dynamodb.yaml` | DynamoDB table (SSE, PITR, TTL) |
| 2 | `ai-content-guard-guardrail` | `guardrail.yaml` | Bedrock Guardrail + 3 SSM params |
| 3 | `ai-content-guard-iam-role` | `iam-role.yaml` | Lambda role (DynamoDB, Bedrock, SSM) |
| 4 | `ai-content-guard-lambda` | `lambda.yaml` | Lambda + CloudWatch Log Group |
| 5 | `ai-content-guard-api-gateway` | `api-gateway.yaml` | REST API, CORS, throttling |
| 6 | `ai-content-guard-amplify` | `amplify.yaml` | Amplify App + SSM param |

## SSM Parameters

| Path | Value |
|------|-------|
| `/ai-content-guard/guardrail/id` | Bedrock Guardrail ID |
| `/ai-content-guard/guardrail/version` | Guardrail version |
| `/ai-content-guard/guardrail/arn` | Guardrail ARN |
| `/ai-content-guard/amplify/app-id` | Amplify App ID |

## Tags

All stacks and resources are tagged with:

| Tag | Value |
|-----|-------|
| `Project` | ai-content-guard |
| `Environment` | production / staging / development |
| `Owner` | utkarsh |
| `ManagedBy` | CloudFormation |
| `Application` | AI-Content-Guard |

## API Reference

### POST /summarize

**Request:**
```json
{ "text": "Your text to summarize (max 10,000 chars)" }
```

**Success (200):**
```json
{ "status": "success", "summary": "Concise 2-3 sentence summary." }
```

**Blocked (422):**
```json
{
  "status": "blocked",
  "reason": "Input content violated safety policy.",
  "message": "Your input contains content that violates our safety policy.",
  "violations": [{"type": "pii_detected", "category": "US_SOCIAL_SECURITY_NUMBER", "action": "BLOCKED"}]
}
```

## Content Safety

- **Blocks:** sexual, violence, hate, insults, misconduct, prompt attacks
- **Anonymizes:** email, phone, name
- **Hard-blocks:** SSN, credit card numbers

## Cleanup

```bash
./destroy.sh
```

Deletes all stacks (including Amplify, DynamoDB, everything) in reverse dependency order. Asks for confirmation.

## License

MIT
