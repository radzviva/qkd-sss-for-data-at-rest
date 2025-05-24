# orchestrator/orchestrator.py
import asyncio
import logging
import base64
import random
from pathlib import Path
import httpx
from httpx import ConnectError
from config.config_loader import load_config, Neighbour, Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("orchestrator")

class Orchestrator:
    def __init__(self, config: Config):
        self.node_id = config.id
        self.role = config.role
        self.neighbours = config.neighbours
        self.threshold = config.threshold
        self.data_dir = Path('data')
        self.client = httpx.AsyncClient(timeout=10)

    async def _wait_for_neighbours(self):
        for neighbour in self.neighbours:
            url = neighbour.url
            while True:
                try:
                    _ = await self.client.get(url)
                    logger.info(f"Connected to {neighbour.id} at {url}")
                    break
                except ConnectError:
                    logger.info(f"Waiting for {neighbour.id} at {url}...")
                    await asyncio.sleep(1)

    async def distribute_files(self):
        src = self.data_dir / 'alice'
        files = list(src.iterdir())
        random.shuffle(files)
        n = len(self.neighbours)
        groups = [files[i::n] for i in range(n)]
        tasks = []
        for neighbour, group in zip(self.neighbours, groups):
            for file_path in group:
                content = base64.b64encode(file_path.read_bytes()).decode()
                payload = {'from': self.node_id, 'to': neighbour.id,
                           'filename': file_path.name, 'content': content}
                url = f"{neighbour.url}/files"
                logger.info(f"POST file {file_path.name} to {neighbour.id}")
                tasks.append(self._post_with_retry(url, payload, neighbour.id, file_path.name))
        await asyncio.gather(*tasks)
        logger.info("All files distributed.")

    async def _post_with_retry(self, url, payload, neighbour_id, filename, retries=5):
        backoff = 1
        for attempt in range(1, retries + 1):
            try:
                r = await self.client.post(url, json=payload)
                if r.status_code == 200:
                    return
                else:
                    logger.error(f"Attempt {attempt}: Error posting {filename} to {neighbour_id}: {r.status_code}")
            except ConnectError as e:
                logger.error(f"Attempt {attempt}: Connection error to {neighbour_id}: {e}")
            await asyncio.sleep(backoff)
            backoff *= 2
        logger.error(f"Failed to POST {filename} to {neighbour_id} after {retries} attempts")

    async def collect_files(self):
        dst = self.data_dir / 'bob'
        dst.mkdir(parents=True, exist_ok=True)
        collected = []
        for neighbour in self.neighbours:
            url = f"{neighbour.url}/files/{neighbour.id}"
            logger.info(f"GET files from {neighbour.id}")
            try:
                resp = await self.client.get(url)
                if resp.status_code == 200:
                    entries = resp.json()
                    for entry in entries:
                        name = entry['filename']
                        data = base64.b64decode(entry['content'])
                        out = dst / name
                        out.write_bytes(data)
                        collected.append(name)
                else:
                    logger.warning(f"{neighbour.id} returned {resp.status_code}")
            except ConnectError as e:
                logger.error(f"Error connecting to {neighbour.id}: {e}")
        logger.info(f"Collected {len(collected)} files: {collected}")

    async def run(self):
        logger.info(f"Node {self.node_id} running as {self.role}")
        if self.role == 'alice':
            await self._wait_for_neighbours()
            await self.distribute_files()
        elif self.role == 'bob':
            await asyncio.sleep(2)
            await self.collect_files()
        await self.client.aclose()

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('-c','--config', required=True)
    args = p.parse_args()
    cfg = load_config(args.config)
    asyncio.run(Orchestrator(cfg).run())