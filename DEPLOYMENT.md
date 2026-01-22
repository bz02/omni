## Omni Web + API Production Deployment (AWS reference)

These steps assume AWS, GitHub, Stripe, Pinecone, and domain at Route53. Adapt to GCP/Azure similarly.

### 1) Prereqs
- Install: `awscli`, `docker`, `node 20`, `python 3.11`, `terraform` or `aws-cdk`.
- Create AWS IAM user/role for CI with least-privilege to ECR, ECS, RDS, CloudFront, SSM, Route53, S3.
- Create Stripe account and a Pinecone index (e.g., `omni-rag`, cosine, 1536 dims).

### 2) Infrastructure (IaC)
1. **Networking**: VPC with 2–3 public + private subnets, NAT gateway. Security groups: ALB (80/443), ECS tasks (allow from ALB), RDS (allow from ECS SG), Redis (optional).
2. **Data**:
   - RDS PostgreSQL `omni` (multi-AZ, storage autoscaling). Parameter group: `rds.force_ssl=1`.
   - S3 `omni-assets` for generated images/exports.
   - Optional: ElastiCache Redis for sessions/queues.
3. **Compute**:
   - ECR repos: `omni-gateway`, `omni-astro`, `omni-rag`.
   - ECS Fargate services behind an ALB:
     - `gateway` (Node.js) – routes APIs, Stripe webhook, auth, rate limiting.
     - `astro` (Python) – ephemeris, transit scheduler (EventBridge cron).
     - `rag` (Python) – embeddings + retrieval to Pinecone.
4. **Frontend**:
   - Option A: Vercel (fastest) pointing to GitHub repo; set env vars in Vercel.
   - Option B: Build Next static export → deploy to S3 + CloudFront with ACM cert.
   - Option C: Next SSR on ECS behind same ALB (add service `web`).
5. **Secrets**: Store in SSM Parameter Store or Secrets Manager:
   - `OPENAI_API_KEY`, `GEMINI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_ENV`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `POSTGRES_URL`, `JWT_SECRET`, `R2`/S3 creds, etc.

### 3) Application wiring
- Replace API stubs in `web/app/api/*` with calls to your `gateway` domain. For local dev, set `NEXT_PUBLIC_API_BASE=http://localhost:3001`.
- Implement PII scrubbing middleware in the gateway before LLM requests.
- Python `astro` service: use Swiss Ephemeris or NASA JPL; expose RPC/REST to gateway.
- RAG service: chunk astrology classics + psychology corpus, embed (OpenAI/Gemini), store in Pinecone. Provide `/rag/query` endpoint.
- Stripe tips: `POST /api/payments/tip` → creates PaymentIntent. Webhook handler at `/webhooks/stripe` updates Postgres and emits receipts.

### 4) CI/CD (GitHub Actions sketch)
- Triggers: on `main`.
- Jobs:
  1. **lint-test**: `npm ci && npm run lint && npm run build` in `web`.
  2. **docker-build-push**: Build/push `gateway`, `astro`, `rag` to ECR (`docker buildx build --platform linux/amd64`).
  3. **migrate**: Run DB migrations (Prisma/Knex/Alembic) against RDS.
  4. **deploy-ecs**: Update ECS services via `aws ecs update-service --force-new-deployment`.
  5. **frontend**: If using S3+CloudFront, `npm run build && npx next export` then `aws s3 sync out/ s3://omni-web/ --delete` and `aws cloudfront create-invalidation --paths "/*"`.

### 5) Domain + HTTPS
- Request ACM cert for `omni.yourdomain.com` and `api.omni.yourdomain.com`.
- Point Route53 A/AAAA to CloudFront (frontend) and ALB (API) via alias.
- Enforce HTTPS redirect on ALB/CloudFront.

### 6) Observability
- Enable OpenTelemetry SDK in Node/Python; export traces/metrics/logs to Datadog/New Relic.
- Health checks: `/healthz` per service, `/readyz` with DB/Pinecone/Stripe checks.
- Alerts: high p95 latency, 5xx rate, failed Stripe webhooks, Pinecone latency, RDS connections, transit scheduler failures.

### 7) Scaling + performance
- ECS Fargate: autoscale on CPU/Memory, and on ALB request count; set task `ulimits` and connection pools.
- Rate limiting: in gateway (Redis token bucket) per IP/user to protect LLM spend.
- Caching: ephemeris results, frequent tarot spreads, Pinecone responses when safe.
- Queues: use SQS for background jobs (transit alerts, report generation).

### 8) Security & compliance
- PII scrubbing before LLM calls; pseudonymous user IDs.
- Key rotation via Secrets Manager; DB encryption at rest; TLS everywhere.
- GDPR/PIPL: consent screens for geolocation/SDKs; clear data retention + deletion APIs.
- Log redaction for names/emails/phones. Maintain audit tables for access to sensitive data.

### 9) Payment webhooks
- Stripe CLI (local): `stripe listen --forward-to localhost:3001/webhooks/stripe`.
- Prod: set webhook endpoint to `https://api.omni.yourdomain.com/webhooks/stripe`; allow only Stripe IPs or verify signatures.
- Handle events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `charge.dispute.created`.

### 10) Smoke test before go-live
- Frontend build + navigation.
- Create tip payment (test card) → webhook updates DB → receipt stored.
- Astrology calculation request returns data; RAG query succeeds.
- Oracle persona streaming works (WebSocket/SSE).
- Transit scheduler cron runs and pushes notification to a test user/device.


