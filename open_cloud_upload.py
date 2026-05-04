#!/usr/bin/env python3
"""
open_cloud_upload.py — bulk upload meshes / images / sounds to Roblox via the
Open Cloud Assets API. Wraps the same pattern used by the existing 60-asset
upload that produced AssetIds.lua.

USAGE:
    export ROBLOX_API_KEY=<your Open Cloud key with Asset:Write>
    export ROBLOX_USER_ID=<your numeric user id>      # OR
    export ROBLOX_GROUP_ID=<your numeric group id>    # creator type

    python3 open_cloud_upload.py <type> <folder>

    type   = mesh | image | sound
    folder = a directory of files to upload

EXAMPLE:
    python3 open_cloud_upload.py mesh  ~/Desktop/kittyraiser_extra_meshes
    python3 open_cloud_upload.py sound ~/Desktop/kittyraiser_sounds
    python3 open_cloud_upload.py image ~/Desktop/kittyraiser_icons

OUTPUT:
    Prints a Lua snippet you paste into AssetIds.lua. Format:
        AssetIds.cop_siren  = "rbxassetid://<id>"

LIMITATIONS (read carefully):
    * Open Cloud audio uploads currently require BOTH a paid Roblox Premium
      membership on the uploader account AND moderation approval (which can
      take minutes-to-hours). Mesh + image upload is instant.
    * Each file <= 20 MB.
    * Filenames become asset display names — keep them short, lowercase,
      underscored (matches the AssetIds key convention).
"""

import os, sys, json, time, mimetypes, pathlib

try:
    import requests
except ImportError:
    print("ERROR: pip install requests", file=sys.stderr)
    sys.exit(2)

API_KEY    = os.environ.get("ROBLOX_API_KEY")
USER_ID    = os.environ.get("ROBLOX_USER_ID")
GROUP_ID   = os.environ.get("ROBLOX_GROUP_ID")
if not API_KEY:
    print("ERROR: set ROBLOX_API_KEY env var (Creator Hub > Open Cloud > API Keys)", file=sys.stderr)
    sys.exit(2)
if not (USER_ID or GROUP_ID):
    print("ERROR: set ROBLOX_USER_ID or ROBLOX_GROUP_ID", file=sys.stderr)
    sys.exit(2)

BASE = "https://apis.roblox.com/assets/v1"

ASSET_TYPE_MAP = {
    "mesh":  "Model",       # FBX/OBJ uploaded as Model containing MeshParts
    "image": "Decal",       # PNG/JPG => Decal asset
    "sound": "Audio",       # MP3/OGG => Audio asset
}

CONTENT_TYPE_MAP = {
    ".obj": "model/obj",
    ".fbx": "model/fbx",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".mp3": "audio/mpeg",
    ".ogg": "audio/ogg",
}

def upload_one(filepath: pathlib.Path, asset_type: str) -> str:
    """Upload one file. Returns the asset id as a string."""
    name = filepath.stem
    creation_ctx = {"creator": {"userId": USER_ID} if USER_ID else {"groupId": GROUP_ID}}
    request_payload = {
        "assetType": asset_type,
        "displayName": name,
        "description": f"KittyRaiser auto-upload {name}",
        "creationContext": creation_ctx,
    }

    files = {
        "request": (None, json.dumps(request_payload), "application/json"),
        "fileContent": (filepath.name,
                        open(filepath, "rb"),
                        CONTENT_TYPE_MAP.get(filepath.suffix.lower(), "application/octet-stream")),
    }
    headers = {"x-api-key": API_KEY}

    r = requests.post(f"{BASE}/assets", headers=headers, files=files, timeout=60)
    if r.status_code != 200:
        raise RuntimeError(f"upload failed for {filepath.name}: {r.status_code} {r.text}")
    op = r.json()
    op_path = op.get("path")
    if not op_path:
        raise RuntimeError(f"no operation path in response: {op}")
    # Poll the operation
    for _ in range(30):
        time.sleep(2)
        rr = requests.get(f"{BASE}/{op_path}", headers=headers, timeout=20)
        if rr.status_code != 200:
            continue
        result = rr.json()
        if result.get("done"):
            asset = result.get("response", {})
            asset_id = asset.get("assetId")
            if not asset_id:
                raise RuntimeError(f"upload finished but no assetId: {result}")
            return str(asset_id)
    raise RuntimeError(f"upload timed out for {filepath.name}")


def main():
    if len(sys.argv) != 3:
        print(__doc__); sys.exit(2)
    kind = sys.argv[1].lower()
    folder = pathlib.Path(sys.argv[2]).expanduser()
    if kind not in ASSET_TYPE_MAP:
        print(f"unknown type {kind}; use one of {list(ASSET_TYPE_MAP)}"); sys.exit(2)
    if not folder.is_dir():
        print(f"folder not found: {folder}"); sys.exit(2)

    asset_type = ASSET_TYPE_MAP[kind]
    valid_ext = {".obj", ".fbx"} if kind == "mesh" else \
                {".png", ".jpg", ".jpeg"} if kind == "image" else \
                {".mp3", ".ogg"}
    files = sorted([p for p in folder.iterdir() if p.suffix.lower() in valid_ext])
    if not files:
        print(f"no {kind} files in {folder}"); sys.exit(0)

    print(f"-- paste these into src/ReplicatedStorage/Modules/AssetIds.lua")
    for fp in files:
        try:
            aid = upload_one(fp, asset_type)
            key = fp.stem  # cop_car, cop_siren, etc.
            # Convention: meshes get "mesh_" prefix
            if kind == "mesh" and not key.startswith("mesh_"):
                key = "mesh_" + key
            print(f'AssetIds.{key:25} = "rbxassetid://{aid}"  -- {fp.name}')
        except Exception as e:
            print(f"-- ERROR uploading {fp.name}: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
