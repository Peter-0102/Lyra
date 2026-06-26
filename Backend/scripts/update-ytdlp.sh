#!/bin/bash
# Update yt-dlp to latest version
# Run daily via cron to keep up with YouTube changes

set -e

pip3 install --no-cache-dir --break-system-packages -U yt-dlp

NEW_VERSION=$(yt-dlp --version)
echo "$(date): yt-dlp updated to ${NEW_VERSION}" >> /var/log/ytdlp-update.log

curl -s -o /dev/null -w "Health check: %{http_code}\n" http://localhost:3000/api/health || true
