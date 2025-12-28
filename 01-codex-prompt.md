# Codex 5.1 — Implementation Prompt (paste into Codex)

You are Codex 5.1 acting as a senior engineer. Implement the following system end-to-end with **no placeholders**, with tests/mocks, and runnable locally + deployable on a VPS.

## Goal
A monorepo containing:
1) **Flutter Web frontend** (Cupertino design, dark/light mode, responsive)
2) **Backend API + webhook receiver** (secure auth, webhook signature verification, Woo REST sync)
3) **PostgreSQL** persistence
4) **Docker Compose** for local + VPS deployment (reverse proxy + HTTPS-ready)

## Hard requirements
- Frontend is **Flutter Web** using **Cupertino widgets** (not Material), supports **dark + light mode** properly.
- Backend is internet-facing and receives WooCommerce webhooks at stable endpoints.
- No WooCommerce API secrets in the Flutter client. Store them server-side only.
- Authentication must be “real” (hashed passwords, secure cookies or JWT+refresh done safely, CSRF protection if cookies, rate limits, lockout/backoff, RBAC admin).
- Webhook handling must verify **Woo signature** using the webhook secret and the **raw request body**.
- On webhook: **do not trust payload** → fetch authoritative order via Woo REST API and upsert into DB.
- Provide a **Settings UI** to configure Woo store URL, REST consumer key/secret, webhook secret, and to trigger an initial **backfill** sync.
- Provide an **Orders Overview UI**: table/list + detail view, filters, status grouping, and summary metrics.
- Provide tests:
  - unit tests: signature verification, auth logic, Woo client
  - integration tests: webhook endpoint → upsert order → query API
  - Flutter widget tests for Settings + Overview screens (mock API)
- Provide docs: `README.md` with setup, env vars, and Woo webhook configuration steps.

## Suggested tech choices (use these unless you have a better justified alternative)
- Backend: **Node.js (TypeScript) + Fastify**, using **Prisma** for Postgres.
- Auth: session via **httpOnly secure cookies** + CSRF token OR JWT with refresh tokens (explain choice in README).
- Reverse proxy: **Caddy** (automatic HTTPS) or Nginx (HTTPS-ready).
- Background jobs: lightweight in-process queue (e.g., p-queue) + idempotency; keep it simple but correct.

## Data model (minimum)
- `users`: id, email (unique), password_hash, role, created_at, last_login_at
- `app_settings`: singleton row storing Woo store URL, **encrypted** consumer key/secret, webhook secret, sync options, created_at/updated_at
- `orders`: id (Woo id), number, status, currency, total, created_at, updated_at, billing/shipping summary, customer note, payment method, etc.
- `order_items`: id, order_id, name, sku, qty, total
- `webhook_deliveries`: id, topic, woo_delivery_id (if present), signature_valid, received_at, processed_at, status, error
- `audit_log`: user_id, action, metadata, timestamp

## API endpoints (minimum)
- `POST /api/auth/login`, `POST /api/auth/logout`, `GET /api/auth/me`
- `GET/PUT /api/settings` (admin only)
- `POST /api/sync/backfill` (admin only; triggers paginated order import)
- `GET /api/orders` with pagination + filters: status, date range, search (name/email/order #), sort by created/updated
- `GET /api/orders/:id`
- Webhooks:
  - `POST /webhooks/woocommerce/order-created`
  - `POST /webhooks/woocommerce/order-updated`
  - `POST /webhooks/woocommerce/order-deleted`
  All must:
  1) validate signature using stored webhook secret
  2) log delivery
  3) enqueue processing
  4) return 200/204 fast

## WooCommerce specifics
- Use Woo REST API v3: `/wp-json/wc/v3/orders`
- On webhook: parse event to get order id if possible; then fetch order via REST and upsert.
- Backfill: paginate through orders, ordered by modified date; support initial “import everything” and incremental sync.
- Support `checkout-draft` optionally (config in settings), but default to paid/normal statuses.

## Frontend pages (Flutter Web, Cupertino)
1) **Login**
2) **Orders Overview**
   - segmented control by status group (e.g., New/Processing/Completed/Cancelled/Refunded + optional Draft)
   - updates via polling (e.g., every 10–20s) against backend `GET /api/orders?modified_after=...`
   - metrics cards: counts per status, gross revenue today/7d, avg order value
3) **Order Detail**
4) **Settings (Admin)**
   - store URL, Woo REST keys, webhook secret
   - button “Test connection”
   - button “Run backfill”
   - show webhook endpoint URLs to copy into WooCommerce
   - toggle: include checkout-draft
   - polling interval configuration

## Security & ops best practices to implement
- Input validation (zod or equivalent)
- Rate limiting on auth + webhook endpoints
- Password hashing (argon2/bcrypt)
- Secure headers (helmet or equivalent)
- CORS locked down (only your frontend origin)
- Encrypted-at-rest storage for Woo credentials (AES-GCM or libsodium; master key from env)
- Health endpoint `GET /healthz`
- Structured logging + request IDs
- Idempotency: avoid duplicate processing for same webhook delivery/order update burst
- DB migrations included and run in docker compose

## Repo structure (required)
- `/backend` (TypeScript backend)
- `/frontend` (Flutter web)
- `/infra` (docker compose, proxy config)
- root `README.md`

## Deliverables
- All code committed as files in the repo structure
- `docker-compose.yml` runs everything locally on `http://localhost` (or HTTPS via Caddy)
- `README.md` includes:
  - local dev steps
  - VPS deployment steps
  - required env vars
  - how to set up Woo webhooks in WooCommerce UI
  - how to create Woo REST keys
- Provide example `.env.example` (no secrets)

Proceed by creating the repo structure, then implementing backend first (auth, settings, webhooks, orders API, tests), then frontend (Cupertino UI + theme, auth flow, pages, API client, tests), then infra and docs.
