import os

def save_text(content: str, filename: str, outbox_dir: str = "data/outbox") -> None:
    """
    Save string content to data/outbox/filename.txt.
    """
    if not os.path.isdir(outbox_dir):
        os.makedirs(outbox_dir)
    path = os.path.join(outbox_dir, filename)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[outbox] Saved {path}")