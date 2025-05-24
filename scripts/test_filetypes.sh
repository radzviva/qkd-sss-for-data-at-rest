#!/usr/bin/env bash
# test_filetypes.sh — AES encrypt/decrypt round‑trip test for all files
# Usage: ./scripts/test_filetypes.sh
set -euo pipefail

# Hardcode project root (parent of scripts/)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Project root: $ROOT"

# Find all files in data_at_rest
mapfile -t files < <(find "$ROOT/data_at_rest" -type f | sort)
if [ ${#files[@]} -eq 0 ]; then
  echo "❌ No files in data_at_rest to test"
  exit 1
fi

declare -a successes
declare -a failures

for TARGET in "${files[@]}"; do
  BASE="$(basename "$TARGET")"
  echo
  echo "🔍 Testing AES round‑trip for file: $BASE"

  # Clean previous AES workspace
  rm -rf "$ROOT/aes/data/inbox/file" \
         "$ROOT/aes/data/inbox/key"  \
         "$ROOT/aes/data/inbox/todo" \
         "$ROOT/aes/data/outbox"      2>/dev/null || true
  mkdir -p "$ROOT/aes/data/inbox/file" \
           "$ROOT/aes/data/inbox/key" \
           "$ROOT/aes/data/inbox/todo" \
           "$ROOT/aes/data/outbox"

  # Stage plaintext
  cp "$TARGET" "$ROOT/aes/data/inbox/file/$BASE"
  # Stage static key
  echo "7f24254aa9a54b5c858eaee2f5bccdb46aaf0e486a595ed5fd8f86ba55232a70" \
    > "$ROOT/aes/data/inbox/key/key"
  # Trigger encryption
  touch "$ROOT/aes/data/inbox/todo/enc"

  # Run encryption
  pushd "$ROOT/aes" >/dev/null
  if ! make run >/dev/null 2>&1; then
    echo "❌ Encryption error for $BASE"
    failures+=("$BASE")
    popd >/dev/null
    continue
  fi
  popd >/dev/null

  # Prepare decryption: clear enc marker, remove plaintext
  rm -f "$ROOT/aes/data/inbox/todo/enc"
  find "$ROOT/aes/data/inbox/file" -type f ! -name "enc_$BASE" -delete
  # Set dec marker
  rm -f "$ROOT/aes/data/inbox/todo/dec"
  touch "$ROOT/aes/data/inbox/todo/dec"
  # Stage encrypted file
  cp "$ROOT/aes/data/outbox/enc_$BASE" "$ROOT/aes/data/inbox/file/enc_$BASE"
  rm -rf "$ROOT/aes/data/outbox"/*

  # Run decryption
  pushd "$ROOT/aes" >/dev/null
  if ! make run >/dev/null 2>&1; then
    echo "❌ Decryption error for $BASE"
    failures+=("$BASE")
    popd >/dev/null
    continue
  fi
  popd >/dev/null

  # Verify
  if cmp -s "$TARGET" "$ROOT/aes/data/outbox/dec_enc_$BASE"; then
    echo "✅ AES round‑trip SUCCESS for $BASE"
    successes+=("$BASE")
  else
    echo "❌ AES round‑trip FAILED for $BASE"
    failures+=("$BASE")
  fi

  rm -rf aes/data/outbox/*
  rm -rf aes/data/inbox/file/*
  rm aes/data/inbox/key/*
  rm aes/data/inbox/todo/*

  echo "AES reset — ready"


done

# Summary
echo
echo "=== AES Round‑trip Summary ==="
echo "Successful: ${#successes[@]}"
for f in "${successes[@]}"; do echo "  - $f"; done

echo "Failed: ${#failures[@]}"
for f in "${failures[@]}"; do echo "  - $f"; done

exit 0
