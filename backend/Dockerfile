FROM node:20-slim AS builder
WORKDIR /app

COPY package*.json tsconfig.json prisma ./
RUN npm ci
COPY src ./src
RUN npm run build && npx prisma generate

FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY entrypoint.sh ./entrypoint.sh

RUN chmod +x entrypoint.sh

EXPOSE 3000

CMD ["./entrypoint.sh"]
