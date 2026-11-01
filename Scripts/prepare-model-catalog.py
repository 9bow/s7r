#!/usr/bin/env python3
"""Refresh pinned public metadata. This script does not download weights."""
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def get(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)

def entries(repo, prefix, destination, selected=None):
    revision = get(f"https://huggingface.co/api/models/{repo}")["sha"]
    url = f"https://huggingface.co/api/models/{repo}/tree/{revision}"
    if prefix:
        url += "/" + prefix
    files = get(url + "?recursive=true")
    result = []
    for item in files:
        if item["type"] != "file":
            continue
        path = item["path"]
        name = path[len(prefix) + 1:] if prefix else path
        if selected is not None and name not in selected:
            continue
        result.append(dict(path=destination + "/" + name, url=f"https://huggingface.co/{repo}/resolve/{revision}/{path}", bytes=item["size"], sha256=item.get("lfs", {}).get("oid")))
    return revision, result

whisper_rev, whisper = entries("argmaxinc/whisperkit-coreml", "openai_whisper-small", "whisper-small")
token_rev, tokenizer = entries("openai/whisper-small", "", "whisper-tokenizer", {"tokenizer.json", "tokenizer_config.json", "special_tokens_map.json", "added_tokens.json", "normalizer.json", "vocab.json", "merges.txt"})
qwen_rev, qwen = entries("mlx-community/Qwen3-4B-Instruct-2507-4bit", "", "qwen3-4b", {"chat_template.jinja", "generation_config.json", "config.json", "model.safetensors", "model.safetensors.index.json", "tokenizer.json", "tokenizer_config.json", "special_tokens_map.json", "added_tokens.json", "vocab.json", "merges.txt"})
nemotron_rev, nemotron = entries("mlx-community/nemotron-3.5-asr-streaming-0.6b-8bit", "", "nemotron-0.6b", {"config.json", "model.safetensors", "tokenizer.model", "vocab.txt"})
models = [dict(id="nemotron", name="Nemotron 3.5 ASR 0.6B 8bit", revision=nemotron_rev, license="OpenMDW-1.1", files=nemotron), dict(id="whisper", name="Whisper small", revision=whisper_rev, tokenizerRevision=token_rev, license="MIT", files=whisper + tokenizer), dict(id="qwen", name="Qwen3-4B-Instruct-2507 4bit", revision=qwen_rev, license="Apache-2.0", files=qwen)]
for model in models:
    model["downloadBytes"] = sum(item["bytes"] for item in model["files"])
(ROOT / "Sources/S7RPlatform/Resources/models.json").write_text(json.dumps(models, indent=2) + "\n")
print([(m["id"], m["downloadBytes"], m["revision"]) for m in models])
