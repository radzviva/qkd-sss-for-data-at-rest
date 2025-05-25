#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ─── Helpers ──────
# Return current time in milliseconds
now_ms() { date +%s%3N; }
# Compute duration between two ms timestamps
dur_ms() { echo $(( $2 - $1 )); }

# ─── Bootstrap ────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"

# ─── Statistics file setup ───────────────────────
STAT_FILE="$ROOT/statistics.csv"
trap 'rm -f "$STAT_FILE"' EXIT

# Compute seconds between two floats
dur_s(){
  awk -v s="$1" -v e="$2" 'BEGIN{printf "%.6f", e - s}'
}

# ─── Step 0: Choose file to encrypt ──────────────
DATA_DIR="data_at_rest"
mapfile -t options < <(find "$ROOT/$DATA_DIR" -maxdepth 1 -type f | sort)
if (( ${#options[@]} == 0 )); then
  echo "### ERROR: No files found in '$DATA_DIR'. Exiting."
  exit 1
fi

echo
echo "Please choose a file from '$DATA_DIR' to send to Bob using your QKD key:"
echo "--------------------------------------------------------------"
for i in "${!options[@]}"; do
  printf "  %2d) %s\n" $((i+1)) "$(basename "${options[i]}")"
done
echo "--------------------------------------------------------------"

while true; do
  read -rp "Enter choice [1-${#options[@]}]: " choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#options[@]} )); then
    sel="${options[choice-1]}"
    base="$(basename "$sel")"
    echo ">> You selected: $base"
    break
  fi
  echo "!! Invalid choice. Please enter a number between 1 and ${#options[@]}."
done

# ─── Ask for Shamir split parameters ─────────────
echo
echo "This file will be protected by a QKD-generated 64-hex key,"
echo "then split with Shamir's Secret Sharing, stored on different servers,"
echo "and finally recombined by Bob to decrypt."
read -rp "Total number of shares to generate (e.g. 5): " NUM_SHARES
read -rp "Threshold number needed to reconstruct (e.g. 3): " THRESHOLD
echo ">> OK: split into $NUM_SHARES shares, threshold = $THRESHOLD"
echo
KEY_MATCH="no"
FILE_MATCH="no"

# ─── Prepare AES inbox for encryption ────────────
mkdir -p "$ROOT/aes/data/inbox/file" "$ROOT/aes/data/inbox/todo"
cp "$sel" "$ROOT/aes/data/inbox/file/"
touch "$ROOT/aes/data/inbox/todo/enc"
echo ">> File '$base' staged in aes/data/inbox for encryption"
echo

# ─── STEP 1: QKD → SSS pipeline ──────────────────
echo "====== STEP 1: QKD → SSS pipeline ======"
docker compose down -v

# QKD key
t0_keygen=$(now_ms)
docker-compose up --build -d
t1_keygen=$(now_ms)

# SSS split
t0_sss_split=$(now_ms)
docker compose exec sss python -m src.cli split \
  --threshold "$THRESHOLD" \
  --num-shares "$NUM_SHARES"
t1_sss_split=$(now_ms)

# Copy shares
t0_copy_shares=$(now_ms)
for f in sss/data/outbox/share_*_alice_raw_key.txt; do
  cp "$f" "$ROOT/shared_keys/alice/split/"
  cp "$f" "$ROOT/shared_keys/alice/shares/priv/"
done
t1_copy_shares=$(now_ms)

docker compose down -v
echo ">> QKD+SSS done. Shares are under shared_keys/alice"
echo

# ─── STEP 1a: Send QKD key to AES ───────────────
echo "====== STEP 1a: Send QKD raw key to AES ======"
t0_key_send=$(now_ms)
mkdir -p "$ROOT/aes/data/inbox"
cp "$ROOT/shared_keys/alice/raw/alice_raw_key.txt" "$ROOT/aes/data/inbox/key"
t1_key_send=$(now_ms)
echo ">> Key copied to aes/data/inbox/key"
echo

# ─── STEP 1b: Run AES encryption ────────────────
echo "====== STEP 1b: AES encryption ======"
t0_aes_enc=$(now_ms)
pushd "$ROOT/aes" >/dev/null
make run
popd >/dev/null
t1_aes_enc=$(now_ms)
echo ">> Encryption output in aes/data/outbox"
echo

# ─── STEP 1c: Distribute encrypted artefact ─────
echo "====== STEP 1c: Distribute encrypted artefact ======"
t0_dist_enc=$(now_ms)
enc_file="enc_${base}"
mkdir -p "$ROOT/shared_keys/alice/shares/pub" "$ROOT/shared_keys/bob/shares/pub"
cp "$ROOT/aes/data/outbox/$enc_file" "$ROOT/shared_keys/alice/shares/pub/"
cp "$ROOT/shared_keys/alice/shares/pub/$enc_file" "$ROOT/shared_keys/bob/shares/pub/"
t1_dist_enc=$(now_ms)
echo ">> Encrypted file published to public shares"
echo

# ─── Cleanup AES before infra ───────────────────
echo "====== Cleanup AES staging files ======"
"$ROOT/scripts/aes_clean.sh"
echo

# ─── STEP 2: Copy Alice shares into infra ──────
echo "====== STEP 2: Copy shares into infrastructure ======"
t0_copy_alice=$(now_ms)
cp "$ROOT/shared_keys/alice/shares/priv/"* "$ROOT/infrastructure/data/alice/"
t1_copy_alice=$(now_ms)
echo ">> Alice shares staged in infrastructure/data/alice"
echo

# ─── STEP 3: Infra HTTP POST/GET ────────────────
echo "====== STEP 3: Distribute & collect via infra ======"
pushd "$ROOT/infrastructure" >/dev/null
docker compose up --build -d server-1 server-2 server-3

t0_post=$(now_ms)
docker compose run --rm alice
t1_post=$(now_ms)

t0_get=$(now_ms)
docker compose run --rm bob
t1_get=$(now_ms)

docker compose down -v
popd >/dev/null
echo ">> Infra POST/GET complete"
echo

# ─── STEP 4: Copy Bob shares back ───────────────
echo "====== STEP 4: Copy Bob shares back ======"
t0_copy_bob=$(now_ms)
cp "$ROOT/infrastructure/data/bob/"* "$ROOT/shared_keys/bob/shares/priv/"
t1_copy_bob=$(now_ms)
echo ">> Bob shares in shared_keys/bob/shares/priv"
echo

# ─── STEP 5: Prepare SSS inbox ──────────────────
echo "====== STEP 5: Prepare SSS inbox ======"
t0_prep_sss=$(now_ms)
rm -rf "$ROOT/sss/data/outbox"/*
mkdir -p "$ROOT/sss/data/inbox"
cp "$ROOT/shared_keys/bob/shares/priv/"* "$ROOT/sss/data/inbox/"
t1_prep_sss=$(now_ms)
echo ">> Shares moved into SSS inbox"
echo

# ─── STEP 6: Combine SSS shares ─────────────────
echo "====== STEP 6: Combine SSS shares ======"
t0_combine=$(now_ms)
pushd "$ROOT/sss" >/dev/null
python3 -m src.cli combine --threshold "$THRESHOLD"
popd >/dev/null
t1_combine=$(now_ms)
mkdir -p "$ROOT/shared_keys/bob/combine"
cp "$ROOT/sss/data/outbox/recovered.txt" "$ROOT/shared_keys/bob/combine/recovered.txt"
echo ">> Combined key in shared_keys/bob/combine/recovered.txt"
echo

# ─── STEP 7: Verify key match ────────────────────
echo "====== STEP 7: Verify key match ======"
if cmp -s "$ROOT/shared_keys/alice/raw/alice_raw_key.txt" \
           "$ROOT/shared_keys/bob/combine/recovered.txt"; then
  KEY_MATCH="yes"
else
  KEY_MATCH="no"
fi
echo ">> Keys match: $KEY_MATCH"
echo

# ─── STEP 8 – Stage & decrypt with AES ─────────────────────────────────────
 echo; echo "▶▶ STEP 8a – Sending SSS recovered key to AES module"
 t0_key_recv=$(now_ms)
 "$ROOT/scripts/aes_clean.sh"
 mkdir -p "$ROOT/aes/data/inbox/file" "$ROOT/aes/data/inbox/key" "$ROOT/aes/data/inbox/todo"
 # copy into key/key so AES sees exactly inbox/key/key
 cp "$ROOT/shared_keys/bob/combine/recovered.txt" "$ROOT/aes/data/inbox/key/key"
 t1_key_recv=$(now_ms)

 echo; echo "▶▶ STEP 8b – Staging encrypted artefact for decryption"
 cp "$ROOT/shared_keys/bob/shares/pub/$enc_file" "$ROOT/aes/data/inbox/file/$enc_file"
 touch "$ROOT/aes/data/inbox/todo/dec"

 # 8c) Run the AES decryption step
echo
echo "▶▶ STEP 8c – Running AES decryption"
t0_aes_dec=$(now_ms)
pushd "$ROOT/aes" >/dev/null

# try a decrypt target, fall back to 'make run'
if make decrypt; then
  : # used the decrypt rule
elif make run; then
  : # fallback
else
  echo "❌ ERROR: neither 'make decrypt' nor 'make run' succeeded in aes/"
  popd >/dev/null
  t1_aes_dec=$(now_ms)
  exit 1
fi

popd >/dev/null
t1_aes_dec=$(now_ms)

dec_file="dec_enc_${base}"
echo "   • Decryption complete → aes/data/outbox/$dec_file"

echo
echo ">>>>> VERIFY decrypted file matches original"


if cmp -s "$sel" "$ROOT/aes/data/outbox/$dec_file"; then
  FILE_MATCH="yes"
else
  FILE_MATCH="no"
fi


echo
echo


# Write CSV
{
  echo "metric,seconds"
  echo "QKD_gen,$(dur_s $t0_keygen   $t1_keygen)"
  echo "SSS_split,$(dur_s $t0_sss_split $t1_sss_split)"
  echo "AES_encrypt,$(dur_s $t0_aes_enc   $t1_aes_enc)"
  echo "Infra_post,$(dur_s $t0_post       $t1_post)"
  echo "Infra_get,$(dur_s $t0_get        $t1_get)"
  echo "SSS_combine,$(dur_s $t0_combine    $t1_combine)"
  echo "AES_decrypt,$(dur_s $t0_aes_dec    $t1_aes_dec)"
} > "$STAT_FILE"


# gif

# 9) Optional GIF visualization
echo
echo "▶▶ STEP 9 – Optional Visualization"
# gif
"$ROOT/scripts/visualize.sh" scripts/simple.gif "$base" "$NUM_SHARES" "$THRESHOLD" annotated.gif


# ─── Performance Summary ────────────────────────
echo "###############################"
echo "# Performance Summary (ms)    #"
echo "###############################"
printf " QKD key gen     : %6s ms\n" "$(dur_ms $t0_keygen   $t1_keygen)"
printf " SSS split        : %6s ms\n" "$(dur_ms $t0_sss_split $t1_sss_split)"
printf " Copy shares      : %6s ms\n" "$(dur_ms $t0_copy_shares $t1_copy_shares)"
printf " AES encrypt      : %6s ms\n" "$(dur_ms $t0_aes_enc   $t1_aes_enc)"
printf " Distribute enc   : %6s ms\n" "$(dur_ms $t0_dist_enc  $t1_dist_enc)"
printf " Infra POST       : %6s ms\n" "$(dur_ms $t0_post       $t1_post)"
printf " Infra GET        : %6s ms\n" "$(dur_ms $t0_get        $t1_get)"
printf " SSS combine      : %6s ms\n" "$(dur_ms $t0_combine    $t1_combine)"
printf " AES decrypt      : %6s ms\n" "$(dur_ms $t0_aes_dec    $t1_aes_dec)"
echo

# Write CSV
{
  echo "metric,seconds"
  echo "QKD_gen,$(dur_s $t0_keygen   $t1_keygen)"
  echo "SSS_split,$(dur_s $t0_sss_split $t1_sss_split)"
  echo "AES_encrypt,$(dur_s $t0_aes_enc   $t1_aes_enc)"
  echo "Infra_post,$(dur_s $t0_post       $t1_post)"
  echo "Infra_get,$(dur_s $t0_get        $t1_get)"
  echo "SSS_combine,$(dur_s $t0_combine    $t1_combine)"
  echo "AES_decrypt,$(dur_s $t0_aes_dec    $t1_aes_dec)"
} > "$STAT_FILE"

echo

# ─── Session Results ─
echo "###########################"
echo "#   Session Results      #"
echo "###########################"
echo " Selected file    : $base"
echo " SSS shares total : $NUM_SHARES"
echo " SSS threshold    : $THRESHOLD"
echo " QKD key match    : $KEY_MATCH"
echo " Decrypted match  : $FILE_MATCH"
echo
echo
echo "###################################"
echo "#   Created supporting files    #"
echo "#################################"
echo ">>>> statistics.csv "
echo ">>>> annotated.gif"
echo
echo
read -rp "Press any key to finish…" -n1
echo

# ─── Final Cleanup 
echo " >>>> Cleaning up AES session files"
"$ROOT/scripts/aes_clean.sh"
echo " >>>> Cleaning up QKD & SSS session files"
"$ROOT/scripts/reset_qkd_sss.sh"
echo " Thank you for using the QKD-AES simulator!"
