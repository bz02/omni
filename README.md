# Omni (万相)

AI-native astrology + tarot + MBTI + Oracle assistant with payment tips.

## Repository layout
- `web/` – Next.js web experience with UI for astrology, tarot, MBTI, Oracle AI, and tipping entry point. Includes API stubs you can wire to real services.
- Future (mobile) – Flutter app can reuse APIs/services defined below.

## Quick start (web)
```bash
cd web
npm install
npm run dev
```

## High-level architecture
- **Frontend (web/mobile)**: Next.js (web) + Flutter (mobile) with shared design tokens. Uses WebSocket for streaming AI responses and push notification registration.
- **API Gateway (Node.js)**: Auth, rate limits, request sanitization (PII stripping), routing to Python services/LLMs, Stripe webhook for tips.
- **Astro Compute (Python)**: Swiss Ephemeris / NASA JPL calculations, house systems, aspect engine, transit tracker scheduler, synastry/composite calculators.
- **AI Layer**: Gemini 3.0 + OpenAI GPT, RAG over astrology classics + modern psychology, Pinecone for embeddings, prompt-layer for persona orchestration.
- **Tarot Engine (Node/Python)**: Fisher–Yates shuffle, spread templates, card orientation logic, 3D flip metadata for UI.
- **Personality Service (Node)**: MBTI Step II questionnaire, scoring, mid-zone interpretation, evolution curves over time, comparison + conflict suggestions.
- **Storage**: PostgreSQL (RDS/Cloud SQL) for users, assessments, payments, audit. Pinecone for semantic search. Object storage (S3/GCS) for assets and generated visuals.
- **Observability**: OpenTelemetry traces/metrics/logs to Datadog/New Relic. Alerting on latency, error rate, webhook failures.
- **Compliance**: PII minimization, consent gates (PIPL), transparency labels, per-region data residency.

## Environment variables (minimum)
Create `web/.env.local` for local dev (example keys):
```
NEXT_PUBLIC_API_BASE=https://api.omni.yourdomain.com
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
PINECONE_API_KEY=...
POSTGRES_URL=postgres://user:pass@host:5432/omni
```

## API stubs (web/app/api)
- `GET /api/astrology` – sample chart/aspect/transit payload.
- `POST /api/tarot` – Fisher–Yates shuffle mock draw.
- `POST /api/mbti` – mock Step II scoring payload.
- `POST /api/oracle` – sample persona reply with memory hint.
- `POST /api/payments` – mock PaymentIntent response.

Replace mocks with real services behind your gateway. Keep PII scrubbing before LLM calls.

## Deployment (AWS reference)
1) **Infra**: Use Terraform or AWS CDK.
   - VPC + public ALB → ECS Fargate services (`gateway`, `python-astro`, `python-rag`).
   - RDS PostgreSQL, S3 for assets, ElastiCache Redis for sessions/queues, CloudFront CDN for `web` static build.
   - Secrets in SSM Parameter Store or Secrets Manager; IAM roles per task.
2) **Frontend**: Build Next.js (`npm run build`) and deploy to Vercel or S3+CloudFront (static export) or Next on ECS/Amplify.
3) **Pinecone**: Create index (e.g., `omni-rag`, cosine, 1536 dims). Store key in Secrets Manager; restrict by VPC peering if available.
4) **Payments**: Create Stripe account, enable webhooks to `https://api.omni.yourdomain.com/webhooks/stripe`. Handle `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`. Store receipts in Postgres.
5) **Migrations**: Use Prisma/Knex for Node or Alembic for Python. Run migrations in CI before deploy.
6) **CI/CD (GitHub Actions)**:
   - On push to `main`: lint + test → build web → build Docker images → push to ECR → deploy ECS service → invalidate CloudFront.
7) **Monitoring**: Enable OpenTelemetry SDKs; ship to Datadog. Add synthetic checks for `/healthz`, Stripe webhook, and transit alert scheduler.

## Security & compliance reminders
- Strip names/phones/email before LLM calls; replace with pseudonymous IDs.
- Consent gating for geolocation/SDK usage (PIPL); no permissions until user accepts.
- Encrypt in transit (TLS) and at rest; restrict DB with security groups; rotate keys.
- Publish transparency label listing data collected, use, retention, and third-party SDKs.
