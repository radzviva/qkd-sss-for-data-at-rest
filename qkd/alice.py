#!/usr/bin/env python3
import socket
import json
import random
import os

# ——— PARAMETERS ———
TARGET_KEY_BITS = 256         # we want 256 bits → 64 hex chars
NUM_BITS = TARGET_KEY_BITS * 4  # send 4× as many to get ~50% matches
BOB_HOST = 'bob'
BOB_PORT = 6000

# ——— 1) Generate random bits & bases ———
alice_bits  = [random.randint(0,1) for _ in range(NUM_BITS)]
alice_bases = [random.choice(['Z','X']) for _ in range(NUM_BITS)]

print("Alice generated", NUM_BITS, "qubits")

# ——— 2) Send on “quantum” channel, receive Bob’s bases ———
with socket.create_connection((BOB_HOST, BOB_PORT)) as sock:
    sock.sendall((json.dumps({
        'type': 'QUANTUM',
        'bits': alice_bits,
        'bases': alice_bases
    }) + '\n').encode())
    bob_bases = json.loads(sock.makefile().readline())['bases']

# ——— 3) Sift: keep only matching‐basis bits ———
matching_indices = [i for i, (a,b) in enumerate(zip(alice_bases, bob_bases)) if a == b]
sifted = [alice_bits[i] for i in matching_indices]
print(f"Sifted down to {len(sifted)} bits")

# ——— 4) Truncate & pack into 256 bits ———
if len(sifted) < TARGET_KEY_BITS:
    raise RuntimeError(f"Only {len(sifted)} sifted bits—need ≥{TARGET_KEY_BITS}. Increase NUM_BITS.")
# take the first 256 bits
key_bits = sifted[:TARGET_KEY_BITS]

# pack into bytes and hex-encode
hex_key = ''.join(
    f"{sum(key_bits[i+j] << (7-j) for j in range(8)):02x}"
    for i in range(0, TARGET_KEY_BITS, 8)
)
assert len(hex_key) == 64

print("Alice’s 64-char hex key:", hex_key)

# ——— 5) Write to file ———
os.makedirs('keys', exist_ok=True)
with open('keys/alice_raw_key.txt', 'w') as f:
    f.write(hex_key)
print("→ Written to keys/alice_raw_key.txt")



# ——— 6) Tell Bob which indices matched so he can derive the same key ———
with socket.create_connection((BOB_HOST, BOB_PORT)) as sock:
    sock.sendall((json.dumps({
        'type': 'MATCH',
        'matches': matching_indices[:TARGET_KEY_BITS]  # only first 256
    }) + '\n').encode())
    ack = json.loads(sock.makefile().readline()).get('status')
    if ack == 'OK':
        print("Key exchange complete.")
    else:
        print("Error in public‐channel exchange.")
