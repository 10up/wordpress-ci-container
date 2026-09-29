#!/bin/bash

# Install the latest N LTS lines of node (default 3), oldest first
# Uses nvm's relative LTS aliases (lts/-2, lts/-1, lts/*), so the weekly rebuild
# rolls the set forward automatically when a new line enters LTS
# nvm can be used in individual pipelines to install other versions

# LTS calendar: https://nodejs.org/en/about/releases/

# catch Errors
set -euo pipefail

# Get number of LTS lines from Docker build argument
LTS_COUNT="${1:-3}"

if [[ ! "${LTS_COUNT}" =~ ^[1-9][0-9]*$ ]]; then
  >&2 echo "ERROR: LTS count must be a positive integer, got '${LTS_COUNT}'"
  exit 1
fi

# set up nvm in this script
. "$NVM_DIR/nvm.sh"

for (( offset = LTS_COUNT - 1; offset >= 0; offset-- )); do
  if [[ "${offset}" -eq 0 ]]; then
    NODE_VERSION="lts/*"
  else
    NODE_VERSION="lts/-${offset}"
  fi

  echo "Building node environment for version ${NODE_VERSION}"
  nvm install "${NODE_VERSION}"
done

npm cache clean --force

echo "node build completed for the latest ${LTS_COUNT} LTS versions..."
