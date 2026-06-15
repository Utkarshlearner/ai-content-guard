# 🛡️ AI Content Guard — Presentation Guide (10 Slides, 60 min)

## How to Start the Session

**Don't open slides first.** Open the app in your browser and say:

> "Before I show any slides, let me show you something. This is an AI summarizer I built. Watch what happens when I paste normal text..."
> *(paste lecture notes → green summary appears)*
>
> "Now watch this..."
> *(paste PII with SSN → red blocked card appears)*
>
> "The AI never even saw that text. It was blocked at the infrastructure level. Today I'll show you how I built this — fully serverless on AWS, costs less than ₹25/month."

**Then open slides.** You've hooked them. Now they want to know how.

---

## Slide 1: Title (1 min)
**AI Content Guard**  
AI Text Summarizer with Safety Guardrails

- Your Name | College | Date
- "Summarize Safely — Block Threats Before They Reach AI"

*(You already did the hook — this slide is just for reference while you briefly introduce yourself)*

---

## Slide 2: Problem + Solution (5 min)
**"AI Without Safety = Risk"**

Problem:
- AI tools process anything — no checks on harmful content or PII
- No audit trail of what was sent to AI

Solution:
- Text summarizer that checks BEFORE and AFTER AI processes
- Blocks violence, hate, PII at infrastructure level
- Full serverless on AWS — zero server management

**❓ Ask:** "What stops someone from pasting Aadhaar or PAN number into ChatGPT?"  
**Answer:** Nothing. That's what we fixed.

---

## Slide 3: Architecture (7 min)
**Show:** `docs/ai-content-guard-architecture.png`

Flow: User → Amplify → API Gateway → Lambda → Guardrail → Bedrock Model → DynamoDB

Key points:
- Guardrail runs TWICE — two separate API calls:
  - **Input check:** "Is the user sending something harmful?" → if yes, block immediately, AI model never called
  - **Output check:** "Did the AI generate something harmful?" → if yes, block before it reaches user
- Blocked content never reaches the AI model
- Every request logged in DynamoDB

**❓ Ask:** "Why check output too? Isn't checking input enough?"  
**Answer:** AI can generate unsafe content even from safe input.

---

## Slide 4: AWS Services (5 min)
**"The Right Tool for Each Job"**

| Service | Role |
|---------|------|
| Lambda | Runs code without servers |
| Bedrock | Generates summary (AI model) |
| Bedrock Guardrails | Blocks unsafe content + PII |
| API Gateway | REST API with throttling |
| DynamoDB | Logs every request |
| SSM Parameter Store | Config without redeployment |
| Amplify | Hosts frontend |
| CloudFormation | Infrastructure as Code |

**❓ Ask:** "How much do you think this costs per month with 100 users?"  
*(Let them guess)* **Answer:** Less than ₹25. Serverless = pay only when used.

---

## Slide 5: Content Safety (5 min)
**"What Gets Blocked"**

- Blocks: Violence, Hate, Sexual, Insults, Misconduct, Prompt Attacks
- Anonymizes: Email, Phone, Name
- Hard-blocks: SSN, Credit Card

**❓ Ask:** "If I type my friend's phone number — block or anonymize?"  
**Answer:** Anonymize! Only SSN and credit cards get fully blocked.

---

## Slide 6: How It Works — Real-Time (5 min)
**"What Happens in 1.5 Seconds"**

```
Input validated → Guardrail checks input (300ms)
  → If unsafe: BLOCKED (returns in 0.4s)
  → If safe: AI summarizes (800ms) → Guardrail checks output
    → Save to DB → Return summary (total 1.5s)
```

Key insight: Blocked = FASTER than success (AI model is never called)

**❓ Ask:** "Why is blocked content faster than a successful summary?"  
**Answer:** Guardrail stops it immediately — model never invoked. Like airport security — if bag has something wrong, you never reach the plane.

---

## Slide 7: Deployment (3 min)
**"One Command to Deploy, One to Destroy"**

```bash
./deploy.sh          # Asks what to deploy
./deploy.sh all      # Deploy all 6 stacks
./deploy-frontend.sh # Deploy UI
./destroy.sh         # Delete everything
```

6 independent stacks — update Lambda without touching DynamoDB.

**❓ Ask:** "Setting this up by clicking in AWS Console — how long?"  
**Answer:** 1-2 hours. With the script? 5 minutes.

---

## Slide 8: Full Live Demo (20 min)
**"Your Turn — Let's Try It Together"**

Demo script:
1. Open the app → show the clean UI
2. Paste lecture notes → green summary card ✅
3. Paste PII (SSN + credit card) → red blocked card 🚫
4. Paste prompt injection → blocked 🚫
5. **Ask audience:** "Give me something to try!" → paste their suggestion

**Keep it conversational:** "See the red card? That means the guardrail caught it. The AI model never even processed this text. It was stopped at the infrastructure level."

---

## Slide 9: What You'll Learn (5 min)
**"Interview-Ready Skills"**

- Serverless architecture (Lambda, DynamoDB, API Gateway)
- AI integration via API (not training — using)
- Content safety at infrastructure level
- Infrastructure as Code (CloudFormation)
- Full-stack (React + REST API)
- Security — least-privilege, encryption, defense in depth

Same patterns used by: Netflix, Swiggy, CRED, Instagram

**❓ Ask:** "How many security layers can you count in this project?"  
**Answer:** 7 — API throttle, input validation, input guardrail, output guardrail, IAM, encryption, logging.

---

## Slide 10: Thank You + Try It Yourself (4 min)
**App URL:** https://main.d1244888rwbz47.amplifyapp.com
**Sample prompts:** `docs/sample-prompts.txt`

**❓ Ask:** "If you had to add ONE feature, what would it be?"  
*(Great discussion starter — authentication, multi-language, dashboard, etc.)*

---

## ⏱️ Timing

| Section | Time |
|---------|------|
| Hook (live demo before slides) | 3 min |
| Slides 1-2: Intro + Problem | 6 min |
| Slides 3-4: Architecture + Services | 12 min |
| Slides 5-6: Safety + Flow | 10 min |
| Slide 7: Deployment | 3 min |
| **Slide 8: Full Live Demo** | **17 min** |
| Slides 9-10: Learnings + Q&A | 9 min |

---

## 💡 Presentation Tips

1. **Start with the app, not slides** — hook them in the first 2 minutes with a live demo
2. **Let audience suggest text** — makes them invested in the outcome
3. **₹25/month cost reveal** — always gets a reaction, use it early
4. **Don't read slides** — slides are minimal, YOU tell the story
5. **End with "Netflix uses the same pattern"** — motivates students
6. **Keep energy up** — one question per slide keeps them alert
