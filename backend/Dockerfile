# syntax=docker/dockerfile:1

FROM node:22-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
# Section 12 Cloud Hosting Optimization: cap V8 heap below Render Free Tier 512 MB RAM limit
ENV NODE_OPTIONS="--max-old-space-size=384"

RUN addgroup -S monevo && adduser -S monevo -G monevo

COPY --from=builder --chown=monevo:monevo /app/package.json ./package.json
COPY --from=builder --chown=monevo:monevo /app/node_modules ./node_modules
COPY --from=builder --chown=monevo:monevo /app/dist ./dist
COPY --chown=monevo:monevo drizzle ./drizzle

USER monevo
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "dist/server.js"]

