# Pinned by digest so a rebuilt image cannot silently change its base; bump deliberately.
FROM node:24-bookworm-slim@sha256:01d566e8d94d8c619591d78652babfccd3c6992a3dffa9ed5ab39e11cf6c70e9
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund && npm cache clean --force
COPY --chown=node:node src ./src
COPY --chown=node:node scripts/migrate.js ./scripts/migrate.js
COPY --chown=node:node scripts/import-legacy-item.js ./scripts/import-legacy-item.js
COPY --chown=node:node migrations ./migrations
USER node
EXPOSE 8080
ENV PORT=8080
CMD ["node", "src/runtime.js", "api"]
