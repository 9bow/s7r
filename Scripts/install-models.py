#!/usr/bin/env python3
"""Install explicitly selected models into the selected cache directory."""
import argparse
import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def digest_file(target):
    digest = hashlib.sha256()
    with target.open("rb") as source:
        while block := source.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()
parser = argparse.ArgumentParser()
parser.add_argument("models", nargs="+", choices=["whisper", "qwen", "nemotron", "qwen-asr", "qwen-aligner"])
parser.add_argument("--accept-license", action="store_true", required=True)
parser.add_argument("--catalog", default="Sources/S7RPlatform/Resources/models.json")
parser.add_argument("--models", dest="model_directory", type=Path, default=Path.home() / ".cache" / "s7r")
args = parser.parse_args()
catalog = json.loads((ROOT / args.catalog).read_text())
for model in catalog:
    if model["id"] not in args.models:
        continue
    for item in model["files"]:
        target = args.model_directory / item["path"]
        if target.exists() and target.stat().st_size == item["bytes"]:
            if not item["sha256"] or digest_file(target) == item["sha256"]:
                continue
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + ".download")
        digest = hashlib.sha256()
        with urllib.request.urlopen(item["url"], timeout=120) as response, temporary.open("wb") as output:
            while block := response.read(1024 * 1024):
                output.write(block)
                digest.update(block)
        if temporary.stat().st_size != item["bytes"] or (item["sha256"] and digest.hexdigest() != item["sha256"]):
            raise RuntimeError("Model integrity mismatch: " + item["path"])
        temporary.replace(target)
        print(item["path"], item["bytes"], flush=True)
    (args.model_directory / (model["id"] + ".installed.json")).write_text(json.dumps(model, indent=2))
