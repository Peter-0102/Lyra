FROM node:20-bookworm-slim AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc && mkdir -p dist/db/migrations && cp src/db/migrations/*.sql dist/db/migrations/

FROM node:20-bookworm-slim

ARG YTDLP_VERSION=

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip ffmpeg curl ca-certificates cron \
    && if [ -n "$YTDLP_VERSION" ]; then \
        pip3 install --no-cache-dir --break-system-packages "yt-dlp==${YTDLP_VERSION}"; \
    else \
        pip3 install --no-cache-dir --break-system-packages yt-dlp; \
    fi \
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

CMD ["node", "dist/server.js"]
