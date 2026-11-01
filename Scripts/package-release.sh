#!/bin/zsh
set -eu
cd "${0:A:h:h}"
release_version=$(<VERSION)
bin_dir="$PWD/.build/out/Products/Release"
name="s7r-${release_version}-macos-arm64"
stage="$PWD/.cache/release/$name"
mkdir -p dist
rm -rf "$stage"
mkdir -p "$stage/cli" "$stage/ThirdParty"
Scripts/package-app.sh "$bin_dir"
ditto s7r.app "$stage/s7r.app"
cp "$bin_dir/s7r" "$stage/cli/s7r"
for bundle in "$bin_dir"/*.bundle; do
    ditto "$bundle" "$stage/cli/${bundle:t}"
done
ln -s mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib "$stage/cli/mlx.metallib"
cp docs/third-party/* "$stage/ThirdParty/"
cp docs/install-release.md "$stage/README.md"
cp VERSION "$stage/"
python3 - "$stage/BUILD-INFO.json" <<'BUILDINFO'
import json, subprocess, sys
from pathlib import Path
commit = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True)
record = {"version": Path("VERSION").read_text().strip(), "configuration": "Release", "architecture": "arm64", "sourceCommit": commit.stdout.strip() if commit.returncode == 0 else None, "sourceDirty": bool(subprocess.check_output(["git", "status", "--porcelain"]).strip())}
Path(sys.argv[1]).write_text(json.dumps(record, indent=2) + "\n")
BUILDINFO
python3 - "$stage/source" <<'PYTHON'
import shutil, subprocess, sys
from pathlib import Path
destination = Path(sys.argv[1])
for entry in subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]).split(b"\0"):
    if not entry:
        continue
    source = Path(entry.decode())
    output = destination / source
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output)
PYTHON
[[ ! -f LICENSE ]] || cp LICENSE "$stage/"
codesign --verify --deep --strict "$stage/s7r.app"
codesign --verify --strict "$stage/cli/s7r"
ditto -c -k --sequesterRsrc --keepParent "$stage" "$PWD/dist/$name.zip"
(cd dist && shasum -a 256 "$name.zip" > SHA256SUMS)
print "$PWD/dist/$name.zip"
