#!/bin/sh
# Prepares a fresh clone: a placeholder seed (real content is built privately) and the Xcode project.
set -eu
cd "$(dirname "$0")/.."

mkdir -p Generated
if [ ! -f Generated/seed.json ]; then
  echo '{"version":1,"decks":[]}' > Generated/seed.json
  echo "Created an empty Generated/seed.json. Run tools/build-seed to fill it from your source export."
fi

xcodegen generate
