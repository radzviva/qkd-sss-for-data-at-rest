#!/usr/bin/env bash
# reset_qkd_sss.sh — bring the workspace back to a pristine state
# ------------------------------------------------------------------
set -euo pipefail

echo "Stopping containers and pruning volumes…"
docker compose down -v 2>/dev/null || true

echo "Removing generated key-material…"
rm -rf \
  shared_keys/alice/{raw,split,shares/{priv,pub}}/* \
  shared_keys/bob/{raw,combine,shares/{priv,pub}}/* 2>/dev/null || true

echo "Removing infrastructure data files…"
rm -rf infrastructure/data/alice/* infrastructure/data/bob/* 2>/dev/null || true

echo "Removing SSS share & recovery files…"
rm -rf sss/data/outbox/* 2>/dev/null || true
rm -rf sss/data/inbox/* 2>/dev/null || true

echo "Removing logs and visualisations…"
rm -rf logs 2>/dev/null || true
rm -f  diagram.png logs/events.json 2>/dev/null || true

rm -rf shared_keys/bob/combined 2>/dev/null || true
rm -rf shared_keys/bob/decrypted 2>/dev/null || true

echo "✅  Workspace reset — ready for the next fresh run."