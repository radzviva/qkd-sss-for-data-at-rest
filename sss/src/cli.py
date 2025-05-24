import argparse
import sys
import os
import logging
from src.inbox.io import get_hex_files
from src.logic.shamir import split_secret, recover_secret
from src.outbox.io import save_text

logging.basicConfig(level=logging.INFO, format='[%(levelname)s] %(message)s')


def cmd_split(args):
    paths = get_hex_files(args.inbox)
    if not paths:
        logging.error(f"Inbox empty: {args.inbox}")
        return
    for path in paths:
        name = os.path.basename(path)
        with open(path, 'r', encoding='utf-8') as f:
            secret = f.read().strip()
        try:
            shares = split_secret(secret, args.threshold, args.num_shares)
            logging.info(f"{len(shares)} shares generated for {name}")
        except ValueError as e:
            logging.warning(f"Skipping {name}: {e}")
            continue
        for idx, share in shares:
            save_text(share, f"share_{idx}_{name}", args.outbox)


def cmd_combine(args):
    paths = get_hex_files(args.inbox)
    shares = []
    for path in paths:
        name = os.path.basename(path)
        if not name.startswith('share_'):
            continue
        idx = int(name.split('_')[1])
        with open(path, 'r', encoding='utf-8') as f:
            share = f.read().strip()
        shares.append((idx, share))
        if len(shares) >= args.threshold:
            break
    if len(shares) < args.threshold:
        logging.error(f"Need {args.threshold} shares, found {len(shares)}")
        return
    try:
        recovered = recover_secret(shares, args.threshold)
        logging.info("Secret recovered successfully.")
        save_text(recovered, "recovered.txt", args.outbox)
    except ValueError as e:
        logging.error(f"Recovery error: {e}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="SSS split/combine CLI for 64-hex secrets")
    sub = parser.add_subparsers(dest='cmd')

    # split command
    sp = sub.add_parser('split', help='Split 64-hex secret into shares')
    sp.add_argument('--inbox', default='data/inbox', help='Directory with secret files')
    sp.add_argument('--outbox', default='data/outbox', help='Directory to write shares')
    sp.add_argument('--threshold', type=int, required=True, help='Min shares to reconstruct')
    sp.add_argument('--num-shares', type=int, required=True, help='Total number of shares to generate')
    sp.set_defaults(func=cmd_split)

    # combine command
    cb = sub.add_parser('combine', help='Combine shares to recover secret')
    cb.add_argument('--inbox', default='data/inbox', help='Directory with share files')
    cb.add_argument('--outbox', default='data/outbox', help='Directory to write recovered secret')
    cb.add_argument('--threshold', type=int, required=True, help='Threshold used for splitting')
    cb.set_defaults(func=cmd_combine)

    args = parser.parse_args()
    if not hasattr(args, 'func'):
        parser.print_help()
        sys.exit(1)
    args.func(args)