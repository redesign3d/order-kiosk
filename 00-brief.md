# OrderKiosk — Implementation Brief (Phase 1)

## Goal
Build a production-ready **OrderKiosk** as a **Flutter Web** app (Cupertino UI, **dark/light mode**) plus a **backend** running on a **dedicated VPS** that:
- receives **WooCommerce webhooks**
- verifies signatures
- fetches authoritative order data via Woo REST API
- stores orders in a database
- serves a secure API to the Flutter frontend

**Phase 1 scope**
- **Authentication**: secure login (email+password), RBAC (admin minimum), rate limiting, basic audit logging.
- **Settings page**: configure Woo connection and kiosk behavior (store URL, REST keys, webhook secret, include drafts, polling interval); test connection; run backfill.
- **Orders overview page**: list + filter/search + status grouping; show summary metrics (counts by status, revenue totals, avg order value, last sync).
- **Webhooks**: `order.created`, `order.updated`, `order.deleted` → log deliveries → enqueue processing → upsert orders.
- **Deployment**: Docker Compose (frontend, backend, Postgres, reverse proxy), env-based config, migrations, health checks, structured logs.

## Non-goals (for now)
- Order management/actions (status changes, refunds, fulfillment) — planned for later expansion.
- Multi-store support — out of scope for Phase 1.

## Key constraints
- **No WooCommerce credentials in Flutter** (server-side only).
- Webhook signature verification must use the **raw request body**.
- Backend must process webhook bursts idempotently (avoid duplicate work).

## Recommended architecture
- `/frontend`: Flutter Web (Cupertino)
- `/backend`: Node.js TypeScript API (Fastify recommended) + Prisma + Postgres
- `/infra`: Docker Compose + reverse proxy (Caddy recommended)
