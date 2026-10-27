FROM node:24-bookworm-slim AS node
FROM swift:6.3.3-noble AS build
COPY --from=node /usr/local/ /usr/local/
WORKDIR /work
COPY Package.swift ./
COPY NomadFi/NomadFi/Core/FiBot/Engine ./NomadFi/NomadFi/Core/FiBot/Engine
COPY services/fibot-engine/Sources ./services/fibot-engine/Sources
COPY services/fibot-engine/Tests ./services/fibot-engine/Tests
COPY NomadFi/NomadFi/Core/PortfolioLab/Engine ./NomadFi/NomadFi/Core/PortfolioLab/Engine
COPY services/portfolio-lab/SwiftTests ./services/portfolio-lab/SwiftTests
COPY services/portfolio-lab/fixtures ./services/portfolio-lab/fixtures
COPY NomadFi/NomadFi/Resources/PortfolioLab ./NomadFi/NomadFi/Resources/PortfolioLab
RUN swift build -c release && swift test
COPY services/plaid-backend/package.json services/plaid-backend/package-lock.json ./services/plaid-backend/
RUN npm ci --prefix services/plaid-backend --no-audit --no-fund
COPY services/plaid-backend/src ./services/plaid-backend/src
COPY services/plaid-backend/migrations ./services/plaid-backend/migrations
COPY services/plaid-backend/scripts ./services/plaid-backend/scripts
COPY services/plaid-backend/test ./services/plaid-backend/test
COPY services/plaid-backend/ops/roles.sql ./services/plaid-backend/ops/roles.sql
RUN useradd --uid 10001 --create-home nomadfi && chown -R nomadfi:nomadfi /work

FROM build AS test
USER nomadfi
WORKDIR /work/services/plaid-backend
RUN FIBOT_TEST_EXECUTABLE=/work/.build/release/fibot-evaluate npm test

FROM build AS production-dependencies
RUN npm prune --prefix services/plaid-backend --omit=dev --ignore-scripts

FROM swift:6.3.3-noble AS runtime
COPY --from=node /usr/local/bin/node /usr/local/bin/node
RUN useradd --uid 10001 --create-home nomadfi
WORKDIR /app
COPY --from=build /work/.build/release/fibot-evaluate /usr/local/bin/fibot-evaluate
COPY --from=production-dependencies /work/services/plaid-backend/node_modules ./node_modules
COPY services/plaid-backend/package.json ./
COPY services/plaid-backend/src ./src
USER nomadfi
ENV FIBOT_ENGINE_PATH=/usr/local/bin/fibot-evaluate
CMD ["node", "src/fibot-runtime.js"]
