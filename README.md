# Omni (万相)

## Native iOS release preparation

The `codex/omni-ios-release` branch contains the native SwiftUI app in `Omni/`, its shared `Omni.xcodeproj` scheme, and isolated tests. The web prototype described below remains a separate implementation.

The iOS workflow verifies a Release archive and the unit, StoreKit, account, memory and reflection journeys using Xcode 26.3 / iOS 26.2 on a GitHub-hosted Mac. It does not sign or upload a build to Apple, and it does not retain build artifacts. Check the actual Actions run before claiming success.

App Store publication is still pending Apple account setup, distribution signing, real public privacy/support URLs, working online services, store products and final submission. See [iOS configuration](Configuration/README.md). No Apple certificates, private keys, session credentials or user data are included.

AI-native astrology + tarot + MBTI + Oracle assistant with payment tips.

## Repository layout
- `web/` – Next.js web experience with UI for astrology, tarot, MBTI, Oracle AI, and tipping entry point.
- **New Features**:
    - **Omni Oracle**: Real-time AI chat connected to OpenAI with 3 distinct personas (Mentor, Healer, Prophet).
    - **Payments**: Tipping system with simulated payment processing and success animations.

## Quick start (web)
1.  Navigate to the web directory:
    ```bash
    cd web
    npm install
    ```
2.  **Important**: Create a `.env.local` file in `web/` and add your OpenAI API Key for the Oracle to work:
    ```
    OPENAI_API_KEY=sk-your-openai-key-here
    ```
3.  Run the development server:
    ```bash
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
OPENAI_API_KEY=sk-... (Required for Oracle)
GEMINI_API_KEY=...
PINECONE_API_KEY=...
POSTGRES_URL=postgres://user:pass@host:5432/omni
```

## API Routes (web/app/api)
- `GET /api/astrology` – sample chart/aspect/transit payload.
- `POST /api/tarot` – Fisher–Yates shuffle mock draw.
- `POST /api/mbti` – mock Step II scoring payload.
- `POST /api/oracle` – **Live**: Connects to OpenAI to generate persona-based responses.
- `POST /api/payments` – **Mock**: Simulates payment processing with success confetti.

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


## Omni account memory backend

This deployment branch adds the isolated Python account/memory service alongside the existing web app. Use [the Render deployment guide](docs/RENDER_DEPLOYMENT.md) and Blueprint path `deploy/render.yaml`. No real Apple or model credentials are stored here; those integrations remain unavailable until configured. CI builds the production container and verifies authentication and persistence with synthetic data.
