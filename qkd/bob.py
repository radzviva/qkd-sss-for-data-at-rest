#!/usr/bin/env python3
import socketserver
import threading
import json
import random
import os

# same TARGET and batch size, for clarity (though Bob just follows Alice’s MATCH list)
TARGET_KEY_BITS = 256

alice_bits  = []
alice_bases = []
bob_bases   = []
bob_results = []

class QKDHandler(socketserver.StreamRequestHandler):
    def handle(self):
        global alice_bits, alice_bases, bob_bases, bob_results
        msg = json.loads(self.rfile.readline().decode().strip())

        if msg['type'] == 'QUANTUM':
            # receive Alice’s qubits
            alice_bits  = msg['bits']
            alice_bases = msg['bases']
            # Bob picks random bases & “measures”
            bob_bases   = [random.choice(['Z','X']) for _ in alice_bits]
            bob_results = [
                bit if a == b else random.randint(0,1)
                for bit, a, b in zip(alice_bits, alice_bases, bob_bases)
            ]
            # reply with Bob’s bases
            self.wfile.write((json.dumps({'bases': bob_bases}) + '\n').encode())

        elif msg['type'] == 'MATCH':
            matches = msg['matches']  # should be first 256 matching indices
            # build Bob’s version of Alice’s 256 bits
            key_bits = [bob_results[i] for i in matches]
            print(f"Bob received {len(key_bits)} bits")

            # pack to hex
            hex_key = ''.join(
                f"{sum(key_bits[i+j] << (7-j) for j in range(8)):02x}"
                for i in range(0, TARGET_KEY_BITS, 8)
            )
            assert len(hex_key) == 64
            print("Bob’s 64-char hex key:", hex_key)

            # write to file
            os.makedirs('keys', exist_ok=True)
            with open('keys/bob_raw_key.txt', 'w') as f:
                f.write(hex_key)
            print("→ Written to keys/bob_raw_key.txt")

            # ACK and shutdown
            self.wfile.write((json.dumps({'status':'OK'}) + '\n').encode())
            threading.Thread(target=self.server.shutdown).start()

if __name__ == '__main__':
    PORT = 6000
    server = socketserver.ThreadingTCPServer(('0.0.0.0', PORT), QKDHandler)
    print(f"Bob’s QKD server listening on port {PORT} …")
    server.serve_forever()
