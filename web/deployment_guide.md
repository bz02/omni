# Omni Deployment Guide

This guide outlines the steps to deploy the Omni application to Vercel with a PostgreSQL database (e.g., Vercel Postgres, Neon, or Supabase).

## Prerequisites

- A GitHub repository with the Omni code.
- A Vercel account.
- A PostgreSQL database provider (Vercel Postgres is recommended for ease of use).

## Step 1: Database Setup

1.  **Create a PostgreSQL Database**:
    *   If using **Vercel**: Go to Storage -> Create -> Postgres.
    *   If using **Neon/Supabase**: Create a new project and get the **Connection String**.

2.  **Get Connection String**:
    *   You need the `POSTGRES_PRISMA_URL` and `POSTGRES_URL_NON_POOLING` (if using Vercel Postgres) or just `DATABASE_URL` (for standard Postgres).
    *   For Vercel Postgres, the connection strings are automatically added to your project environment variables when you link it.

## Step 2: Environment Variables

Configure the following Environment Variables in your Vercel Project Settings:

| Variable | Description | Example Value |
| :--- | :--- | :--- |
| `NEXTAUTH_URL` | The canonical URL of your site. | `https://your-project.vercel.app` |
| `NEXTAUTH_SECRET` | A random string for session encryption. | `openssl rand -base64 32` |
| `OPENAI_API_KEY` | Your OpenAI API Key for AI features. | `sk-proj-...` |
| `POSTGRES_PRISMA_URL` | Connection string for Prisma (Pooling). | `postgres://...` |
| `POSTGRES_URL_NON_POOLING` | Direct connection string (Required for Vercel/Neon). | `postgres://...` |

> **Note:** If using a standard Postgres provider (not Vercel), you might just need `DATABASE_URL`. Update `prisma/schema.prisma` and `prisma.config.ts` if your provider setup differs significantly from Vercel Postgres standards, though the current setup is standard for most.

## Step 3: Deployment

1.  Push your code to **GitHub**.
2.  Import the repository in **Vercel**.
3.  Vercel will detect Next.js.
4.  Adding the Environment Variables (Step 2) is critical *before* the build finishes, or the build might fail if it tries to connect to the DB (though typically build just generates client).
5.  **Build Command**: Vercel default (`next build`) is correct.
6.  **Install Command**: Vercel default (`npm install`) is correct.

## Step 4: Database Migration

After deployment (or during build if configured), you need to apply the schema to your production database.

**Option A: Vercel Console / Terminal**
1.  You can run the migration command from your local machine if you have the production connection string in your `.env` file (be careful!).
    ```bash
    npx prisma migrate deploy
    ```

**Option B: Build Script (Advanced)**
Add `"postinstall": "prisma generate"` to your `package.json` (already standard).
To run migrations on deploy, you often update the Build Command in Vercel to:
`npx prisma migrate deploy && next build`
*However, be cautious as this can slow down builds or fail if DB is unreachable.*

**Recommended**: Run `npx prisma migrate deploy` locally pointing to the prod DB *once* or use the Vercel integration dashboard if available.

## Troubleshooting

-   **Prisma Client Error**: If you see "PrismaClient is not a constructor", ensure `npx prisma generate` runs during build (it should by default in Next.js).
-   **Connection Error**: Check if your IP is allowed to access the database or if the connection string is correct.

## Post-Deployment

-   Visit your URL.
-   **Login**: The first time you login with any username/password, a new User account is created (auto-registration/guest mode as implemented).
-   **Test**: Try a Tarot reading to verify it saves to the database.
