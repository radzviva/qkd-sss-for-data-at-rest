#!/usr/bin/env bash
# aes_clean.sh — wipe out any leftover AES session artefacts
# ------------------------------------------------------------------
set -euo pipefail

echo "Removing AES session files…"

# Remove all files (including hidden) under outbox
rm -rf aes/data/outbox/* aes/data/outbox/.[!.]* aes/data/outbox/..?* || true
# Remove all files (including hidden) under inbox/file
rm -rf aes/data/inbox/file/* aes/data/inbox/file/.[!.]* aes/data/inbox/file/..?* || true
# Remove all files under inbox/key
rm -rf aes/data/inbox/key/* aes/data/inbox/key/.[!.]* aes/data/inbox/key/..?* || true
# Remove all files under inbox/todo
rm -rf aes/data/inbox/todo/* aes/data/inbox/todo/.[!.]* aes/data/inbox/todo/..?* || true

echo "AES reset — ready"
