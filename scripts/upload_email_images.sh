#!/usr/bin/env bash
# Uploads email header images to the R2 `assets` bucket under `static/emails/`.
# Requires `wrangler` (https://developers.cloudflare.com/workers/wrangler/) and
# a Cloudflare login with access to the bucket (`wrangler login`).
#
# Filenames should be content-hashed (e.g. onboarding-overview-d9e12.png) so the
# immutable Cache-Control below is safe: a changed image gets a new filename/URL.
#
# Usage:
#   scripts/upload_email_images.sh <path> [<path> ...]
#   scripts/upload_email_images.sh path/to/dir

set -euo pipefail

BUCKET="assets"
CACHE_CONTROL="public, max-age=31536000, immutable"
export CLOUDFLARE_ACCOUNT_ID="0a0e6f92decf825364b860e2286ceebf" # Jiki

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <path> [<path> ...]" >&2
  exit 1
fi

upload_one() {
  local path="$1"
  local filename ext content_type
  filename="$(basename "$path")"
  ext="${filename##*.}"
  ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

  case "$ext" in
    jpg|jpeg) content_type="image/jpeg" ;;
    png)      content_type="image/png"  ;;
    gif)      content_type="image/gif"  ;;
    webp)     content_type="image/webp" ;;
    *) echo "Skipping $path (unsupported extension .$ext)" >&2; return ;;
  esac

  local key="static/emails/$filename"
  echo "Uploading $path → r2://$BUCKET/$key"
  wrangler r2 object put "$BUCKET/$key" \
    --file="$path" \
    --content-type="$content_type" \
    --cache-control="$CACHE_CONTROL" \
    --remote
}

for arg in "$@"; do
  if [ -d "$arg" ]; then
    shopt -s nullglob nocaseglob
    for f in "$arg"/*.{jpg,jpeg,png,gif,webp}; do
      upload_one "$f"
    done
    shopt -u nullglob nocaseglob
  elif [ -f "$arg" ]; then
    upload_one "$arg"
  else
    echo "Skipping $arg (not a file or directory)" >&2
  fi
done
