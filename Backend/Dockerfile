FROM node:20-bookworm-slim AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc && mkdir -p dist/db/migrations && cp src/db/migrations/*.sql dist/db/migrations/

FROM node:20-bookworm-slim

ARG YTDLP_VERSION=2026.06.20

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip ffmpeg curl ca-certificates cron \
    && pip3 install --no-cache-dir --break-system-packages "yt-dlp==${YTDLP_VERSION}" \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY scripts/update-ytdlp.sh /usr/local/bin/update-ytdlp.sh
RUN chmod +x /usr/local/bin/update-ytdlp.sh

RUN mkdir -p /var/log && \
    echo "0 6 * * * root /usr/local/bin/update-ytdlp.sh >> /var/log/ytdlp-update.log 2>&1" > /etc/cron.d/ytdlp-update && \
    chmod 0644 /etc/cron.d/ytdlp-update && \
    crontab /etc/cron.d/ytdlp-update

WORKDIR /app

COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./

RUN mkdir -p /data/audio

VOLUME ["/data"]

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:3000/api/health || exit 1

CMD ["node", "dist/server.js"]
