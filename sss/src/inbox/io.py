import os
from typing import List

def get_hex_files(inbox_dir: str = "data/inbox") -> List[str]:
    """
    Scan data/inbox and return paths to all .txt files containing 64-hex secrets.
    """
    if not os.path.isdir(inbox_dir):
        os.makedirs(inbox_dir)
    return [os.path.join(inbox_dir, f)
            for f in sorted(os.listdir(inbox_dir))
            if f.lower().endswith('.txt')]