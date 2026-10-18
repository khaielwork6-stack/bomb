#!/usr/bin/env python3
"""FUSE VALLEY asset uploader: Roblox Open Cloud Assets API, owned by the game's group.

Uploads a file as a Roblox asset owned by 99 Dreams Studio (the group that owns the game), waits for Roblox to
process it, and prints the asset id (rbxassetid://…). Agents use this instead of asking a human to upload.

  python3 tools/upload.py <file> [--name "Display Name"] [--type Audio|Animation|Decal|Model|Video] [--desc "…"]

The type is inferred from the extension (.wav/.mp3/.ogg/.flac → Audio, .rbxm/.rbxmx → Animation, .png/.jpg/.bmp/
.tga → Decal, .fbx/.glb/.gltf → Model, .mp4/.mov → Video); pass --type Model for an .rbxm that's a model.

The API key is read from ~/.config/fusevalley/roblox_api_key (never from the repo, never printed). Create it once:
create.roblox.com → switch to the group → Open Cloud → API Keys → Create; Access Permissions: Assets API, Read +
Write. Limits: 20 MB a file; audio ≤ 7 min and 10 uploads in total (100 a month once the key owner is ID-verified).
Standard library only (no pip installs).
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

GROUP_ID = 3774675  # 99 Dreams Studio: the game's owner (game.CreatorId)
KEY_PATH = os.path.expanduser("~/.config/fusevalley/roblox_api_key")
API = "https://apis.roblox.com/assets/v1"

TYPES = {
    ".wav": ("Audio", "audio/wav"),
    ".mp3": ("Audio", "audio/mpeg"),
    ".ogg": ("Audio", "audio/ogg"),
    ".flac": ("Audio", "audio/flac"),
    ".rbxm": ("Animation", "model/x-rbxm"),
    ".rbxmx": ("Animation", "model/x-rbxm"),
    ".png": ("Decal", "image/png"),
    ".jpg": ("Decal", "image/jpeg"),
    ".jpeg": ("Decal", "image/jpeg"),
    ".bmp": ("Decal", "image/bmp"),
    ".tga": ("Decal", "image/tga"),
    ".fbx": ("Model", "model/fbx"),
    ".glb": ("Model", "model/gltf-binary"),
    ".gltf": ("Model", "model/gltf+json"),
    ".mp4": ("Video", "video/mp4"),
    ".mov": ("Video", "video/mov"),
}


def api_key() -> str:
    try:
        with open(KEY_PATH, "r", encoding="utf-8") as f:
            key = f.read().strip()
    except FileNotFoundError:
        sys.exit(f"No API key at {KEY_PATH}. Create one (see the top of tools/upload.py) and save it there.")
    if not key:
        sys.exit(f"{KEY_PATH} is empty.")
    return key


def call(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        sys.exit(f"Roblox answered {e.code}: {detail}")


def upload(path: str, name: str, kind: str, mime: str, desc: str) -> str:
    key = api_key()
    request = {
        "assetType": kind,
        "displayName": name[:50],
        "description": desc[:1000],
        "creationContext": {"creator": {"groupId": str(GROUP_ID)}},
    }
    boundary = "----fv" + uuid.uuid4().hex
    with open(path, "rb") as f:
        content = f.read()
    parts = [
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n".encode(),
        json.dumps(request).encode(),
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; "
        f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: {mime}\r\n\r\n".encode(),
        content,
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    op = call("POST", f"{API}/assets", key, b"".join(parts), f"multipart/form-data; boundary={boundary}")
    op_id = (op.get("path") or "").split("/")[-1] or op.get("operationId")
    if not op_id:
        sys.exit(f"Unexpected answer: {op}")
    for _ in range(60):  # Roblox processes the upload; poll until done (≈1–30 s)
        status = call("GET", f"{API}/operations/{op_id}", key)
        if status.get("done"):
            res = status.get("response") or {}
            asset_id = res.get("assetId")
            if not asset_id:
                sys.exit(f"Upload finished without an asset id: {status}")
            moderation = (res.get("moderationResult") or {}).get("moderationState", "?")
            print(f"rbxassetid://{asset_id}  ({kind}, moderation: {moderation})")
            return str(asset_id)
        time.sleep(1.5)
    sys.exit(f"Still processing after 90 s (operation {op_id}); check create.roblox.com.")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("file")
    ap.add_argument("--name")
    ap.add_argument("--type", dest="kind")
    ap.add_argument("--desc", default="FUSE VALLEY (99 Dreams Studio), made in-house.")
    a = ap.parse_args()
    ext = os.path.splitext(a.file)[1].lower()
    kind, mime = TYPES.get(ext, (None, mimetypes.guess_type(a.file)[0]))
    kind = a.kind or kind
    if not kind or not mime:
        sys.exit(f"Can't tell what {a.file} is; pass --type.")
    if os.path.getsize(a.file) > 20 * 1024 * 1024:
        sys.exit("Over the 20 MB limit.")
    name = a.name or os.path.splitext(os.path.basename(a.file))[0]
    upload(a.file, name, kind, mime, a.desc)


if __name__ == "__main__":
    main()
