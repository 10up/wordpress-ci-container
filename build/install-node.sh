#!/bin/bash

# Install only the current LTS version and npm packages
# This avoids extra GB of build container image size and maintains security
# nvm can be used in individual pipelines to install other versions

# LTS calendar: https://nodejs.org/en/about/releases/

# TODO: NODE_VERSION variable could be centralized in the Dockerfile for quicker management

# catch Errors
set -euo pipefail

# Updated install-node.sh due to the following issue, fixed in a more specific LTS version of 16 (v16.20.2 - gallium):
NODE_VERSION="v16.20.2"

# set up nvm in this script
. "$NVM_DIR/nvm.sh"

echo "Building node environment for version ${NODE_VERSION}"

nvm install "${NODE_VERSION}"

npm install -g \
    grunt-cli \
    gulp-cli \
    bower \
    yarn \
    lighthouse \
    serverless \
    firebase-tools \
    cypress

npm cache clean --force

echo "node ${NODE_VERSION} build completed..."

nvm alias default ${NODE_VERSION}
