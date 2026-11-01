#!/bin/zsh
set -eu
cd "${0:A:h:h}"
exec xcodebuild test -project UITests/FinderDrop.xcodeproj -scheme FinderDrop -destination 'platform=macOS' -derivedDataPath .cache/finder-ui-derived -resultBundlePath "docs/evidence/finder-drop-$(date +%Y%m%d-%H%M%S).xcresult"
