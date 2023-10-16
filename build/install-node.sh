#!/bin/bash

# Install only the current LTS version and npm packages
# This avoids extra GB of build container image size and maintains security
# nvm can be used in individual pipelines to install other versions

# LTS calendar: https://nodejs.org/en/about/releases/

# TODO: NODE_VERSION variable could be centralized in the Dockerfile for quicker management

# catch Errors
set -euo pipefail

# Updated install-node.sh due to the following issue, fixed in a more specific LTS version of 16 (v16.20.2 - gallium):
# This strategy targets highest LTS for this release, not a speciifc version
NODE_VERSION="16"

# set up nvm in this script
. "$NVM_DIR/nvm.sh"

echo "Building node environment for version ${NODE_VERSION}"

nvm install "${NODE_VERSION}"

# Cypress version added since latest supports v18.x and above. Setting Cypress version to 13.1.0 according to cypress changelog for supporting node v16.x releases.
# Lighthouse breaking changes for [v11.x / latest](https://github.com/GoogleChrome/lighthouse/releases/tag/v11.0.0), release tag for Aug 4, 2023. Setting latest stable version for node 16 support. (~10.4)
npm install -g \
    grunt-cli \
    gulp-cli \
    bower \
    yarn \
    lighthouse@~10.4 \
    serverless \
    firebase-tools \
    cypress@~13.1

npm cache clean --force

echo "node ${NODE_VERSION} build completed..."

nvm alias default ${NODE_VERSION}
