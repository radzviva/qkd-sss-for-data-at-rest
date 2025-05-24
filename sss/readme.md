# THE KEYS
64HEX in file_name.txt in /data/inbox/

# TO SPLIT
python3 -m src.cli split --threshold 3 --num-shares 5

# TO COMBINE
python3 -m src.cli combine --threshold 3

# TO TEST
pytest