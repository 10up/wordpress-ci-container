#!/bin/bash

# Wrapper script for running a default set of scripts on every deploy
# All scripts are deployed to the `/10up-scripts/` directory which is also added
# to PATH, but calling directly just to be sure

# Catch Errors
set -euo pipefail

. /10up-scripts/php-syntax.sh
. /10up-scripts/virus-scan.sh
