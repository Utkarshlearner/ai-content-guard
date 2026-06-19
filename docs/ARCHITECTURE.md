# AI Content Guard - Architecture Document

## Overview

AI Content Guard is a serverless AI-powered text summarization application with built-in content safety guardrails. It accepts user text via a React frontend, processes it through AWS Lambda with Amazon Bedrock for summarization, and applies Amazon Bedrock Guardrails to block harmful, abusive, and PII-containing content.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                           │
│                                                                             │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────┐  │
│  │   Amplify   │     │   API Gateway    │     │     Lambda Function     │  │
│  │  (Frontend) │────▶│  (REST API)      │────▶│     (Python 3.12)       │  │
│  │             │◀────│  POST /summarize  │◀────│                         │  │
│  └─────────────┘     └──────────────────┘     └────────────┬────────────┘  │
│                                                             │               │
│                       ┌─────────────────────────────────────┼─────────┐     │
│                       │                                     │         │     │
│              ┌────────▼────────┐   ┌───────────────┐   ┌───▼───────┐ │     │
│              │ Bedrock         │   │   Bedrock     │   │ DynamoDB  │ │     │
│              │ Guardrails      │   │   Nova Lite   │   │ (Logs)    │ │     │
│              │ (Content Safety)│   │   (Summary)   │   │           │ │     │
│              └────────┬────────┘   └───────────────┘   └───────────┘ │     │
│                       │                                               │     │
│              ┌────────▼────────┐                                      │     │
│              │ SSM Parameter   │                                      │     │
│              │ Store (Config)  │──────────────────────────────────────┘     │
│              └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

## AWS Services Used

| Service | Purpose | Documentation |
|---------|---------|---------------|
| AWS Lambda | Serverless compute for text processing | [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html) |
| Amazon Bedrock | AI model invocation (Nova Lite) | [Bedrock User Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/) |
| Amazon Bedrock Guardrails | Content filtering, PII detection | [Guardrails Sensitive Filters](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-sensitive-filters.html) |
| Amazon API Gateway | REST API endpoint with CORS | [API Gateway CORS](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html) |
| Amazon DynamoDB | Request/response logging | [DynamoDB PITR](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html) |
| AWS SSM Parameter Store | Runtime configuration for guardrail | [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) |
| AWS Amplify Hosting | Static site hosting for React UI | [Amplify Hosting](https://docs.aws.amazon.com/amplify/latest/userguide/deploy--from-amplify-console.html) |
| AWS CloudFormation | Infrastructure as Code | [CloudFormation Lambda](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-lambda-function.html) |

## Request Flow

### Successful Summarization

```
1. User types text in React UI
2. Frontend POSTs to API Gateway /summarize
3. API Gateway invokes Lambda (proxy integration)
4. Lambda fetches guardrail config from SSM (cached on cold start)
5. Lambda applies Bedrock Guardrail on INPUT text
   → Result: NONE (content is safe)
6. Lambda invokes Bedrock Nova Lite model for summarization
7. Lambda applies Bedrock Guardrail on OUTPUT summary
   → Result: NONE (summary is safe)
8. Lambda saves record to DynamoDB (30-day TTL)
9. Lambda returns 200 with summary
10. Frontend displays green success card
```

### Blocked Content

```
1. User types harmful/PII text in React UI
2. Frontend POSTs to API Gateway /summarize
3. API Gateway invokes Lambda (proxy integration)
4. Lambda applies Bedrock Guardrail on INPUT text
   → Result: GUARDRAIL_INTERVENED (content blocked)
   → Violations extracted (category, type, confidence)
5. Lambda saves blocked record to DynamoDB
6. Lambda returns 422 with violation details
7. Frontend displays red blocked card with violation types
```

## Infrastructure Design

### Separation of Concerns

Each AWS resource is deployed as an independent CloudFormation stack. This enables:
- Independent updates without affecting other resources
- Granular rollback per component
- Clear ownership and tagging per resource
- Parallel development across team members

### Deployment Order & Dependencies

```
Stack 1: dynamodb      ─┐
Stack 2: guardrail     ─┼──▶ Stack 3: iam-role ──▶ Stack 4: lambda ──▶ Stack 5: api-gateway ──▶ Stack 6: amplify
                        │
                        └─── (ARNs passed as parameters)
```

### SSM Parameter Store Strategy

Configuration that the Lambda needs at runtime is stored in SSM rather than passed as CloudFormation parameters to the Lambda environment variables. This provides:

- **Decoupled updates** — Update guardrail version in SSM without redeploying Lambda
- **Single source of truth** — All consumers read the same parameter
- **Audit trail** — SSM provides version history and change tracking

| Parameter | Writer | Reader |
|-----------|--------|--------|
| `/ai-content-guard/guardrail/id` | guardrail.yaml | Lambda (runtime) |
| `/ai-content-guard/guardrail/version` | guardrail.yaml | Lambda (runtime) |
| `/ai-content-guard/guardrail/arn` | guardrail.yaml | Reference |
| `/ai-content-guard/amplify/app-id` | amplify.yaml | deploy-frontend.sh |

### Lambda Design

The Lambda function uses inline code via CloudFormation's `Code.ZipFile` property. This is suitable because:
- The function is a single Python file (~150 lines)
- No external dependencies (only `boto3` which is in the Lambda runtime)
- No S3 bucket needed for deployment artifacts
- Code changes deploy instantly via `cloudformation deploy`

Reference: [AWS::Lambda::Function Code](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-lambda-function-code.html)

### API Gateway Integration

The API uses **Lambda proxy integration** (`AWS_PROXY`). API Gateway passes the complete HTTP request to Lambda as an event object, and Lambda returns a structured response with statusCode, headers, and body.

Reference: [Lambda Proxy Integration](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html)

Response format from Lambda:
```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*"
  },
  "body": "{\"status\": \"success\", \"summary\": \"...\"}"
}
```

### DynamoDB Table Design

| Attribute | Type | Purpose |
|-----------|------|---------|
| `requestId` (PK) | String | Unique request identifier |
| `createdAt` (SK) | String | ISO timestamp for ordering |
| `inputText` | String | Truncated input (first 1000 chars) |
| `summary` | String | Generated summary (if successful) |
| `status` | String | SUCCESS / BLOCKED_INPUT / BLOCKED_OUTPUT |
| `guardrailAction` | String | GUARDRAIL_INTERVENED / NONE |
| `ttl` | Number | Auto-delete after 2 days |

Features enabled:
- **PAY_PER_REQUEST** — No capacity planning needed
- **SSE** — Server-side encryption at rest
- **PITR** — Point-in-time recovery for data protection
- **TTL** — Automatic cleanup of old records (2 days)

Reference: [DynamoDB Point-in-time Recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html)

## Content Safety

### Bedrock Guardrails Configuration

The guardrail applies to both INPUT (user text) and OUTPUT (generated summary):

**Content Filters (HIGH strength on input & output):**
| Category | Input | Output |
|----------|-------|--------|
| SEXUAL | HIGH | HIGH |
| VIOLENCE | HIGH | HIGH |
| HATE | HIGH | HIGH |
| INSULTS | HIGH | HIGH |
| MISCONDUCT | HIGH | HIGH |
| PROMPT_ATTACK | MEDIUM | NONE |

**Topic Policies (DENY — request rejected if detected):**
| Topic | Description |
|-------|-------------|
| WeaponsInstructions | How to build weapons, explosives, harmful devices |
| DrugManufacturing | How to synthesize illegal drugs or controlled substances |
| HackingInstructions | How to hack systems, steal data, bypass security |
| SelfHarm | Content promoting self-harm or suicide |

**Word Policy:**
| Type | Purpose |
|------|---------|
| Custom word list | Explicit blocked words (sex, porn, nude, etc.) |
| AWS Managed PROFANITY | Catches thousands of variations including spacing ("s e x"), mixed case ("SeX"), leet-speak ("s3x"), misspellings |

**PII Handling — ANONYMIZE (text still processed, PII masked):**
| PII Type | Action | Example Output |
|----------|--------|----------------|
| NAME | ANONYMIZE | `{NAME}` |
| EMAIL | ANONYMIZE | `{EMAIL}` |
| PHONE | ANONYMIZE | `{PHONE}` |
| ADDRESS | ANONYMIZE | `{ADDRESS}` |
| AGE | ANONYMIZE | `{AGE}` |
| USERNAME | ANONYMIZE | `{USERNAME}` |
| URL | ANONYMIZE | `{URL}` |
| IP_ADDRESS | ANONYMIZE | `{IP_ADDRESS}` |
| MAC_ADDRESS | ANONYMIZE | `{MAC_ADDRESS}` |
| DRIVER_ID | ANONYMIZE | `{DRIVER_ID}` |
| LICENSE_PLATE | ANONYMIZE | `{LICENSE_PLATE}` |
| VEHICLE_IDENTIFICATION_NUMBER | ANONYMIZE | `{VEHICLE_IDENTIFICATION_NUMBER}` |

**PII Handling — BLOCK (entire request rejected with 422):**
| PII Type | Action | Reason |
|----------|--------|--------|
| CREDIT_DEBIT_CARD_NUMBER | BLOCK | Financial fraud risk |
| CREDIT_DEBIT_CARD_CVV | BLOCK | Financial fraud risk |
| CREDIT_DEBIT_CARD_EXPIRY | BLOCK | Financial fraud risk |
| US_BANK_ACCOUNT_NUMBER | BLOCK | Financial fraud risk |
| US_BANK_ROUTING_NUMBER | BLOCK | Financial fraud risk |
| INTERNATIONAL_BANK_ACCOUNT_NUMBER | BLOCK | Financial fraud risk |
| SWIFT_CODE | BLOCK | Financial fraud risk |
| PIN | BLOCK | Financial fraud risk |
| US_SOCIAL_SECURITY_NUMBER | BLOCK | Identity theft risk |
| US_PASSPORT_NUMBER | BLOCK | Identity theft risk |
| US_INDIVIDUAL_TAX_IDENTIFICATION_NUMBER | BLOCK | Identity theft risk |
| UK_NATIONAL_HEALTH_SERVICE_NUMBER | BLOCK | Identity theft risk |
| UK_NATIONAL_INSURANCE_NUMBER | BLOCK | Identity theft risk |
| UK_UNIQUE_TAXPAYER_REFERENCE_NUMBER | BLOCK | Identity theft risk |
| CA_HEALTH_NUMBER | BLOCK | Identity theft risk |
| CA_SOCIAL_INSURANCE_NUMBER | BLOCK | Identity theft risk |
| PASSWORD | BLOCK | Security risk |
| AWS_ACCESS_KEY | BLOCK | Security risk |
| AWS_SECRET_KEY | BLOCK | Security risk |

**Regex Patterns (custom detection beyond built-in PII):**
| Pattern Name | Detects | Action |
|--------------|---------|--------|
| DateDMY | "11 Jan 1993", "11/01/1993" | ANONYMIZE |
| DateMDY | "January 11, 1993", "Jan 11 1993" | ANONYMIZE |
| DateISO | "1993-01-11" | ANONYMIZE |
| BornYear | "born in 1993", "date of birth 1993" | ANONYMIZE |
| AgeYearsOld | "32 years old", "aged 32", "32-year-old" | ANONYMIZE |
| USZipCode | "10001", "10001-1234" | ANONYMIZE |
| IndianPinCode | 6-digit Indian PIN codes | ANONYMIZE |
| IndianPhone | "+91 9876543210" | ANONYMIZE |
| InternationalPhone | "+44 7911123456" | ANONYMIZE |
| SocialMediaHandle | "@username" | ANONYMIZE |
| AadhaarNumber | "1234 5678 9012" (12-digit) | BLOCK |
| PANNumber | "ABCDE1234F" | BLOCK |
| RoomAptNumber | "room no 23", "apt 4B", "suite 500" | ANONYMIZE |

Reference: [Bedrock Guardrails Sensitive Information Filters](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails-sensitive-filters.html)

## Frontend Architecture

### Tech Stack
- **React 19** — UI components
- **Vite 8** — Build tool and dev server
- **Plain CSS** — No framework, CSS variables for theming

### Key Features
- Auto-retry on 5xx errors (2 retries, 1s/2s backoff)
- Dark mode via `prefers-color-scheme` media query
- Responsive layout (mobile-first)
- Character counter with max validation
- Result cards with status-specific styling

### Hosting
- AWS Amplify Hosting (manual ZIP deployment)
- SPA rewrite rule for client-side routing
- `VITE_API_URL` baked in at build time

## Security

### IAM (Least Privilege)

The Lambda execution role has only the permissions it needs:

| Policy | Permissions | Scope |
|--------|-------------|-------|
| AWSLambdaBasicExecutionRole | CloudWatch Logs | Managed policy |
| dynamodb-policy | PutItem, GetItem, Query | Table ARN only |
| bedrock-policy | InvokeModel | Foundation models + inference profiles |
| bedrock-policy | ApplyGuardrail | Specific guardrail ARN only |
| ssm-policy | GetParameter, GetParameters | `/ai-content-guard/guardrail/*` only |

### API Gateway
- Regional endpoint (no edge locations)
- Throttling: 100 req/s rate, 50 burst
- CORS configured for cross-origin access

### DynamoDB
- Server-side encryption (SSE) enabled
- Input text truncated to 1000 chars before storage
- 2-day TTL auto-deletes records

## Tagging Strategy

All resources tagged consistently for cost allocation, ownership, and governance:

| Tag | Value | Purpose |
|-----|-------|---------|
| Project | ai-content-guard | Cost allocation |
| Environment | production | Environment separation |
| Owner | utkarsh | Ownership |
| ManagedBy | CloudFormation | Drift detection |
| Application | AI-Content-Guard | Application grouping |

## Cost Considerations

| Service | Pricing Model | Estimated Cost (low traffic) |
|---------|--------------|------------------------------|
| Lambda | Per invocation + duration | ~$0.00 (free tier: 1M requests/month) |
| Bedrock Nova Lite | Per token | ~$0.001 per request |
| Bedrock Guardrails | Per assessment | ~$0.001 per assessment |
| DynamoDB | Per request | ~$0.00 (free tier: 25 WCU/RCU) |
| API Gateway | Per request | ~$0.00 (free tier: 1M calls/month) |
| Amplify Hosting | Per GB served | ~$0.00 (free tier: 15 GB/month) |

## Monitoring & Observability

### Lambda Logging

Structured logs with request ID correlation:
```
[request_id] Request received
[request_id] Input length: 330 chars
[request_id] Step 1: Applying input guardrail
[request_id] Input guardrail result: action=NONE, violations=0
[request_id] Step 2: Invoking model amazon.nova-lite-v1:0
[request_id] Summary generated: 180 chars
[request_id] Step 3: Applying output guardrail
[request_id] Step 4: Saving to DynamoDB
[request_id] ✓ SUCCESS | summary_length=180
```

### CloudWatch Log Group
- Retention: 14 days
- Log group: `/aws/lambda/ai-content-guard-summarizer`

## Deployment

```bash
# Deploy all infrastructure
./deploy.sh all

# Deploy only guardrail (auto-updates SSM + redeploys Lambda)
./deploy.sh guardrail

# Deploy frontend to Amplify
./deploy-frontend.sh

# Destroy everything
./destroy.sh
```

### Guardrail Deployment Flow

When running `./deploy.sh guardrail`, the script performs:

1. **Deploy CloudFormation stack** — Creates/updates the guardrail resource config (DRAFT)
2. **Create new version via CLI** — Runs `aws bedrock create-guardrail-version` which preserves old versions (unlike CloudFormation which deletes them)
3. **Update SSM parameters** — Writes the new guardrail ID and version to SSM Parameter Store
4. **Force redeploy Lambda** (only if Lambda exists):
   - Deploys Lambda CloudFormation stack (picks up code changes)
   - Updates env var `GUARDRAIL_CACHE_BUST` with new timestamp (forces cold start)
   - Publishes new Lambda version (guarantees fresh execution environment)

> **Note:** On first-time deployment (`./deploy.sh all`), the Lambda doesn't exist yet at step 2, so the redeploy is skipped. Lambda gets deployed normally at step 4.

### Guardrail Versioning Strategy

- **CloudFormation** manages the guardrail configuration (content filters, PII entities, word policy, regex patterns)
- **CLI** creates published versions (`aws bedrock create-guardrail-version`) — this preserves all old versions for rollback
- **SSM Parameter Store** holds the active version number that Lambda reads at runtime
- To rollback: update SSM `/ai-content-guard/guardrail/version` to an older version number

### Lambda Input Normalization

Before sending text to the guardrail, Lambda normalizes it to defeat evasion tricks:

| Evasion Trick | Example Input | Normalized To |
|---------------|---------------|---------------|
| Spaced characters | "S E X" | "SEX" |
| Dot-separated | "S.E.X" | "SEX" |
| Special chars between letters | "f*ck", "s#it" | "fck", "sit" |
| Leet-speak | "s3x", "p0rn" | "sex", "porn" |
| Repeated characters | "fuuuck", "sexxxx" | "fuck", "sex" |
| Letter-swap anagrams | "FCUK", "SXE" | appends "fuck", "sex" for guardrail to catch |

This ensures the word policy catches all variations without needing to manually list every evasion pattern.
