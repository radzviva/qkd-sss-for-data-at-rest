# storage_server/app.py
from fastapi import FastAPI, HTTPException
app = FastAPI()
# in-memory store: receiver_id -> list of {'from', 'filename', 'content'}
store = {}

@app.post("/files")
async def receive_file(payload: dict):
    to = payload.get('to')
    frm = payload.get('from')
    fname = payload.get('filename')
    content = payload.get('content')
    if to is None or frm is None or fname is None or content is None:
        raise HTTPException(status_code=400, detail="Missing field in payload")
    store.setdefault(to, []).append({'from': frm, 'filename': fname, 'content': content})
    return {'ok': True}

@app.get("/files/{receiver_id}")
async def get_files(receiver_id: str):
    # Always return a list, even if empty
    files = store.pop(receiver_id, [])
    return files
