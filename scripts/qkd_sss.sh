#!/usr/bin/env bash
#
# Description:
#   Handles steps 1 (QKD keygen), 1a (SSS split),
#   and copying shares to shared_keys/alice.
# Usage:
#   $0 <threshold> <num_shares>
#
threshold=$1
num_shares=$2

# --- insert your QKD keygen call here ---
# e.g. qkd_keygen --out keyfile

# --- SSS split ---
python3 -m src.cli split \
  --threshold "${threshold}" \
  --shares "${num_shares}" \
  --infile keyfile \
  --outdir shared_keys/alice/shares

# Copy shares to alice’s pub folder
cp shared_keys/alice/shares/* shared_keys/alice/shares/pub/
