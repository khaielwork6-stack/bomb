"""Upload PNGs (as images) and FBX files (as models) to Roblox with the Open Cloud Assets API.

    python upload_assets.py <folder> --group <groupId> [--key-file PATH] [--prefix NAME]
    python upload_assets.py <folder> --user <userId>  [--key-file PATH]

Uploads every *.png / *.fbx in <folder> not already listed in <folder>/ids.json, waits for each operation and
records name -> asset id in ids.json (re-running only uploads new files; delete a key to re-upload that file).

The API key is read from --key-file (default: ~/.roblox-key, or $ROBLOX_KEY_FILE) and is never printed. It needs
the "asset:read" and "asset:write" scopes for the group or user you upload to.

PNG uploads become Decals: the returned id is the DECAL. In Studio, the image id is
InsertService:LoadAsset(decalId):FindFirstChildWhichIsA("Decal", true).Texture
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API = "https://apis.roblox.com/assets/v1/"
TYPES = {".png": ("Decal", "image/png"), ".fbx": ("Model", "model/fbx")}


def load_key(path: Path) -> str:
    key = path.read_text(encoding="utf-8-sig").strip()
    if not key:
        sys.exit(f"API key file is empty: {path}")
    return key


def call(key, method, path, body=None, ctype=None):
    headers = {"x-api-key": key}
    if ctype:
        headers["Content-Type"] = ctype
    req = urllib.request.Request(API + path, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code}: {e.read().decode(errors='replace')[:400]}")


def upload(key, f: Path, creator: dict, prefix: str):
    asset_type, mime = TYPES[f.suffix.lower()]
    request = {
        "assetType": asset_type,
        "displayName": f"{prefix} {f.stem}".strip(),
        "description": f"{prefix} asset".strip(),
        "creationContext": {"creator": creator},
    }
    b = uuid.uuid4().hex
    body = b"".join(
        [
            f'--{b}\r\nContent-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n'.encode()
            + json.dumps(request).encode()
            + b"\r\n",
            f'--{b}\r\nContent-Disposition: form-data; name="fileContent"; filename="{f.name}"\r\n'
            f"Content-Type: {mime}\r\n\r\n".encode()
            + f.read_bytes()
            + b"\r\n",
            f"--{b}--\r\n".encode(),
        ]
    )
    op = call(key, "POST", "assets", body, f"multipart/form-data; boundary={b}")
    path = op.get("path") or ("operations/" + op.get("operationId", ""))
    for _ in range(90):
        if op.get("done"):
            resp = op.get("response", {})
            return resp.get("assetId"), resp.get("moderationResult", {}).get("moderationState")
        time.sleep(2)
        op = call(key, "GET", path)
    return None, "timeout"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--group", help="group id to own the assets")
    who.add_argument("--user", help="user id to own the assets")
    ap.add_argument("--key-file", default=os.environ.get("ROBLOX_KEY_FILE", str(Path.home() / ".roblox-key")))
    ap.add_argument("--prefix", default="", help="name prefix for the uploaded assets (e.g. the game or map name)")
    a = ap.parse_args()

    folder = Path(a.folder)
    creator = {"groupId": str(a.group)} if a.group else {"userId": str(a.user)}
    ids_file = folder / "ids.json"
    ids = json.loads(ids_file.read_text()) if ids_file.exists() else {}
    key = load_key(Path(a.key_file).expanduser())
    for f in sorted(p for p in folder.iterdir() if p.suffix.lower() in TYPES and not p.stem.startswith("_")):
        if f.stem in ids:
            continue
        asset_id, state = upload(key, f, creator, a.prefix)
        print(f.stem, asset_id, state)
        if asset_id:
            ids[f.stem] = asset_id
            ids_file.write_text(json.dumps(ids, indent=2))


if __name__ == "__main__":
    main()
