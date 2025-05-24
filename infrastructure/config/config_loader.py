# config/config_loader.py
import yaml
from pathlib import Path
from dataclasses import dataclass
from typing import List, Union

@dataclass
class Neighbour:
    id: str
    url: str

@dataclass
class Config:
    id: str
    role: str
    neighbours: List[Neighbour]
    threshold: int


def load_config(path: Union[str, Path]) -> Config:
    data = yaml.safe_load(Path(path).read_text())
    neighbours = [Neighbour(**n) for n in data.get('neighbours', [])]
    return Config(
        id=data['id'],
        role=data['role'],
        neighbours=neighbours,
        threshold=int(data.get('threshold', 0))
    )