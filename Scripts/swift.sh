#!/bin/zsh
set -eu
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.cache/modules"
export SWIFT_MODULECACHE_PATH="$PWD/.cache/modules"
exec swift "$1" --cache-path .cache/spm --config-path .cache/config --security-path .cache/security --disable-sandbox "${@:2}"
