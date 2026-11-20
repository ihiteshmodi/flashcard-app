#!/bin/sh
# Prepares a fresh clone: a placeholder seed (real content is built privately) and the Xcode project.
set -eu
cd "$(dirname "$0")/.."

mkdir -p Generated
if [ ! -f Generated/seed.json ]; then
  echo '{"version":1,"decks":[]}' > Generated/seed.json
  echo "Created an empty Generated/seed.json. Run tools/build-seed to fill it from your source export."
fi
if [ ! -f Generated/game-cards.json ]; then
  echo '{"version":1,"sets":[]}' > Generated/game-cards.json
  echo "Created an empty Generated/game-cards.json. Run tools/build-game-cards to fill it from the print-and-play PDFs."
fi

xcodegen generate
