#!/bin/bash
# Update yt-dlp to latest version
# Run daily via cron to keep up with YouTube changes

set -e

pip3 install --no-cache-dir --break-system-packages -U yt-dlp

echo "$(date): yt-dlp updated to $(yt-dlp --version)" >> /var/log/ytdlp-update.log
