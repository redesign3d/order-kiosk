# OrderKiosk

Production-ready kiosk stack for WooCommerce orders. The repo ships a Fastify/Prisma backend with secure auth + webhook processing, a Flutter Web (Cupertino) frontend, and Docker Compose with Caddy, Postgres, and static hosting.

## Repository layout

- `backend/` — Fastify API, webhook receiver, Prisma schema, tests
- `frontend/` — Flutter Web app (Cupertino, dark/light, widget tests)
- `infra/` — Caddy config
- `docker-compose.yml` — local/VPS stack (backend, frontend, db, proxy)
- `00-brief.md`, `01-codex-prompt.md` — project brief and prompt

## Quickstart (Docker Compose)

1. Copy env defaults and edit secrets:
   ```bash
   cp .env.example .env
   ```
   Ensure `APP_ENCRYPTION_KEY` is a 32-byte base64 string and set admin credentials you want.
2. Build and start:
   ```bash
   docker compose up --build
   ```
3. Open `http://localhost` (Caddy) and log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`.
4. API health: `curl http://localhost:3000/healthz`.

Services/ports:
- proxy (Caddy) :80 → frontend + `/api` & `/webhooks` → backend
- backend :3000 (exposed for debugging)
- frontend (nginx) :8080 (served behind Caddy)
- postgres :5432 (internal)

## Local development (without compose)

### Backend
```bash
cd backend
cp .env.example .env   # edit DATABASE_URL, APP_ENCRYPTION_KEY, ADMIN creds, FRONTEND_ORIGIN
npm install
npx prisma migrate dev
npm run dev            # Fastify on :3000
npm test               # runs migrations + vitest
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome          # dev server
flutter test
```
The web client talks to `/api/...` on the same origin. When using a different host/port in dev, set `FRONTEND_ORIGIN` on the backend accordingly.

## Environment variables

Key vars (see `.env.example` and `backend/.env.example`):
- `DATABASE_URL` — Postgres connection (`postgresql://postgres:postgres@db:5432/orderkiosk`)
- `APP_ENCRYPTION_KEY` — 32-byte base64/hex key for encrypting Woo credentials
- `FRONTEND_ORIGIN` — allowed CORS origin (e.g., `http://localhost`)
- `ADMIN_EMAIL` / `ADMIN_PASSWORD` — seeded admin account on boot
- `SESSION_TTL_HOURS`, `RATE_LIMIT_MAX`, `WEBHOOK_QUEUE_CONCURRENCY` — auth/queue tuning

## Auth & security
- httpOnly cookie session + per-request CSRF header for mutations
- Argon2 password hashing, RBAC (admin), rate limiting on auth/webhooks
- Secure headers via Helmet, strict CORS, request IDs, audit logs on auth/settings/backfill
- Woo secrets encrypted at rest with `APP_ENCRYPTION_KEY`

## WooCommerce setup
1. In Woo, create REST API keys (read-only) for the store.
2. Set the keys + webhook secret in **Settings → WooCommerce connection** inside OrderKiosk.
3. Configure webhooks in WooCommerce:
   - Topic: `Order created` → URL: `http://<your-domain>/webhooks/woocommerce/order-created`
   - Topic: `Order updated` → URL: `http://<your-domain>/webhooks/woocommerce/order-updated`
   - Topic: `Order deleted` → URL: `http://<your-domain>/webhooks/woocommerce/order-deleted`
   - Secret: the same webhook secret stored in settings
4. Use “Test connection” in the settings page, then run “Backfill” for existing orders.

## Running migrations in containers

The backend container runs `prisma migrate deploy` on start via `entrypoint.sh`. For manual runs inside compose:
```bash
docker compose run --rm backend npx prisma migrate deploy
```

## Tests
- Backend: `cd backend && npm test`
- Frontend: `cd frontend && flutter test`

## Deployment notes
- Swap Caddyfile for your domain/TLS (`infra/Caddyfile`); enable automatic HTTPS with email/host config.
- Set strong `APP_ENCRYPTION_KEY`, `ADMIN_PASSWORD`, and DB credentials before deploying.
- Expose only the proxy (port 80/443); backend/front ports can stay internal.
