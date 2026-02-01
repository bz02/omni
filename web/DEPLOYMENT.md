# Omni Deployment Guide

This guide describes how to deploy the Omni application to production.

## Architecture Overview
Omni is currently structured as a monolithic Next.js application containing both the frontend and the mock API layer (simulating Microservices).

- **Frontend**: Next.js (React)
- **Backend API**: Next.js API Routes (`/api/*`)
- **Database**: PostgreSQL (Prisma recommended for future integration)
- **Vector DB**: Pinecone (for RAG features)

## Option 1: Vercel (Recommended for Speed)
The easiest way to deploy this particular architecture is Vercel, as it natively supports Next.js API routes without extra configuration.

### Prerequisites
- A GitHub/GitLab/Bitbucket account
- A Vercel account

### Steps
1.  **Push to Git**: Ensure your code is pushed to a remote repository.
2.  **Import Project**:
    - Go to [Vercel Dashboard](https://vercel.com).
    - Click "Add New..." -> "Project".
    - Select your repository (`omni`).
3.  **Configure Project**:
    - **Framework Preset**: Next.js
    - **Root Directory**: `web` (IMPORTANT: The Next.js app is inside the `web` folder)
4.  **Environment Variables**:
    Add the following variables (even if using mocks, good practice to set them):
    ```
    NEXT_PUBLIC_API_BASE_URL=https://your-deployment-url.vercel.app
    STRIPE_SECRET_KEY=sk_test_... (or mock)
    OPENAI_API_KEY=sk_... (if connecting real LLMs)
    ```
5.  **Deploy**: Click "Deploy". Vercel will build and launch your site.

### Stripe Payment Configuration
To enable the payment/tipping feature:
1.  **Create Stripe Account**: Go to [dashboard.stripe.com](https://dashboard.stripe.com) and sign up.
2.  **Get API Keys**: 
    - Go to Developers -> API Keys.
    - Copy the **Secret Key** (`sk_live_...` or `sk_test_...`).
3.  **Environment Variables**:
    - Set `STRIPE_SECRET_KEY` in Vercel to your Secret Key.
    - Set `NEXT_PUBLIC_API_BASE` in Vercel to your production URL (e.g., `https://omni-web.vercel.app`).
        - *Important*: This is mostly used for the redirect back to your site after payment.

## Option 2: AWS (Docker / ECS)
For a more robust, "cloud-native" deployment as requested in the PRD.

### Prerequisites
- AWS CLI configured
- Docker installed

### Steps

#### 1. Containerize
Create a `Dockerfile` in the `web` directory:

```dockerfile
FROM node:18-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
CMD ["node", "server.js"]
```

#### 2. Build & Push
```bash
cd web
docker build -t omni-web .
# Tag and push to ECR
aws ecr create-repository --repository-name omni-web
docker tag omni-web:latest <your-account-id>.dkr.ecr.<region>.amazonaws.com/omni-web:latest
docker push <your-account-id>.dkr.ecr.<region>.amazonaws.com/omni-web:latest
```

#### 3. Deploy to ECS Fargate
1.  **Create Cluster**: Go to ECS -> Create Cluster -> Fargate.
2.  **Task Definition**: Create a new Task Definition.
    - Image: Your ECR URI.
    - CPU/Memory: 0.5 vCPU / 1GB.
    - Port Mappings: 3000.
3.  **Service**: Create a Service.
    - Desired tasks: 1 (enable Auto-scaling for production).
    - Load Balancer: Create an ALB listening on Port 80/443, forwarding to target group on Port 3000.

## Database Provisioning
For the full experience, you need a Postgres DB and Pinecone Index.

### PostgreSQL (AWS RDS)
1.  Create an RDS instance (PostgreSQL 14+).
2.  Allow access from your ECS Security Group.
3.  Set `DATABASE_URL` env var in your ECS Task Definition.

### Pinecone
1.  Sign up at [Pinecone.io](https://pinecone.io).
2.  Create Index: `omni-index` (Dimensions: 1536 for OpenAI embeddings).
3.  Get API Key and Environment.

## CI/CD (GitHub Actions)
Add `.github/workflows/deploy.yml` to automate deployments:

```yaml
name: Deploy to Production
on:
  push:
    branches: [ "main" ]
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker Image
        run: docker build ./web -t omni-web
      # Add steps to push to ECR/Vercel here
```
