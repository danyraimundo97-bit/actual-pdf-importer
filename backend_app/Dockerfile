# syntax=docker/dockerfile:1

# Only backend_app is deployable; the Flutter client is built separately and
# is not part of this image. Build context is backend_app/.

# ---- build ---------------------------------------------------------------
FROM node:22-bookworm-slim AS build
WORKDIR /app

# better-sqlite3 (the payee->category memory) is a native module. npm uses a
# prebuilt binary when one exists for the platform and otherwise compiles
# from source, which needs a toolchain — notably on arm64 (Raspberry Pi).
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Drop devDependencies but keep the native module already compiled above, so
# the runtime stage needs no compiler.
RUN npm prune --omit=dev

# ---- runtime -------------------------------------------------------------
FROM node:22-bookworm-slim AS runtime
#ENV NODE_ENV=production
WORKDIR /app

# All persistent state lives under /data (see docker-compose.yml). Created
# owned by `node` here because Docker copies this directory's ownership onto
# a fresh named volume — without it the unprivileged process can't write.
RUN mkdir -p /data && chown node:node /data

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./

USER node
EXPOSE 3000

# GET /health is the one route that needs no auth token.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/server.js"]
