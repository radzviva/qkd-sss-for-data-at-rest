#!/usr/bin/env bash
# run_qkd_sss.sh  — full QKD→SSS pipeline with step logs
# --------------------------------------------------------------------
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <THRESHOLD> <NUM_SHARES>"
  echo "  THRESHOLD   # of shares required to reconstruct the key"
  echo "  NUM_SHARES  # total shares to generate"
  exit 1
fi

THRESHOLD="$1"
NUM_SHARES="$2"

#--- directory scaffolding ---
mkdir -p shared_keys/alice/{raw,split,shares/{priv,pub}}
mkdir -p shared_keys/bob/{raw,combine,shares/{priv,pub}}

LOG_DIR="${LOG_DIR:-logs}"
mkdir -p "$LOG_DIR"

step_n=1
step () {
  local label="$1"; shift
  local logf
  printf -v logf "%s/%02d_%s.log" "$LOG_DIR" "$step_n" "$label"
  echo -e "\n▶▶ STEP $step_n – $label  ($(date '+%F %T'))" | tee -a "$logf"
  "$@" 2>&1 | tee -a "$logf"
  step_n=$((step_n+1))
}

# 1. stop & wipe old containers/volumes (just in case)
step down        docker compose down -v

# 2. build + start everything
step up_build    docker compose up --build -d

# 3. split Alice raw key (SSS reads from shared_keys/alice/raw)
step split_alice docker compose exec sss \
                     python -m src.cli split \
                       --threshold "$THRESHOLD" \
                       --num-shares "$NUM_SHARES"

# 4. copy shares → shared_keys/alice/{split,shares/priv}
step copy_shares bash -c '
  mkdir -p shared_keys/alice/{split,shares/priv}
  shopt -s nullglob
  for f in sss/data/outbox/share_*_alice_raw_key.txt; do
    cp "$f" shared_keys/alice/split/
    cp "$f" shared_keys/alice/shares/priv/
    echo "copied $(basename "$f")"
  done
'

# 5. shutdown everything – artefacts stay on disk
step cleanup     docker compose down -v

echo -e "\n✅ Pipeline complete."
echo    "   • Raw key       : shared_keys/alice/raw/alice_raw_key.txt"
echo    "   • Shares (stage): sss/data/outbox/share_*"
echo    "   • Shares (bus)  : shared_keys/alice/split/"
echo    "   • Shares (priv) : shared_keys/alice/shares/priv/"
echo    "   • Logs          : $LOG_DIR/"
