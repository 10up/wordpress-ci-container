#!/bin/bash

# catch Errors
set -euo pipefail

# Downlaod latest WPCLI utility
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

# Validate the wp-cli
WPCLI_VALIDATE=$(php wp-cli.phar --info > /dev/null 2>&1; echo $?)
if [[ "$WPCLI_VALIDATE" -ne 0 ]]
then
  echo 'Error in wp-cli file'
  exit 1
fi

# Install WPCLI  
#chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp-cli.phar

# Add an alias for wp without --allow-root
echo 'alias wp="php /usr/local/bin/wp-cli.phar --allow-root"' >> ~/.bashrc
