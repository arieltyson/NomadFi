FROM node:24-bookworm-slim
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
