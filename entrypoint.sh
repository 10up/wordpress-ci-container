#!/bin/sh

# set up nvm in this script
. "${NVM_DIR}/nvm.sh"

if [ -n "${PRIVATE_KEY}" ]; then
  echo "${PRIVATE_KEY}" > /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
fi

if [ -n "${PUBLIC_KEY}" ]; then
  echo "${PUBLIC_KEY}" > /root/.ssh/id_rsa.pub
fi

if [ -z "${TERMINUS_TOKEN}" ]; then
  echo "TERMINUS_TOKEN is not set, skipping terminus setup.";
else
  echo "TERMINUS_TOKEN is set. Logging In.";
  terminus auth:login --machine-token="${TERMINUS_TOKEN}"
fi

# Set git user.name if GIT_USER_NAME env variable is present
if [ -n "${GIT_USER_NAME}" ]; then
  echo "Setting Git user.name to ${GIT_USER_NAME}"
  git config --global user.name "${GIT_USER_NAME}"
fi

 # Set git user.email if GIT_USER_EMAIL env variable is present
if [ -n "${GIT_USER_EMAIL}" ]; then
  echo "Setting Git user.email to ${GIT_USER_EMAIL}"
  git config --global user.email "${GIT_USER_EMAIL}"
fi

# Set custom composer configs if COMPOSER_CONFIG env variable is present
if [ -n "${COMPOSER_CONFIG}" ]; then
  echo "Setting composer configs - ${COMPOSER_CONFIG}"
  /usr/local/bin/composer config -g "${COMPOSER_CONFIG}"
fi

# Some CI/CD tools require cache to be in the working directory and not
# in default Composer or npm locations, so we use custom paths
# In GitLab, BUILD_CACHE_DIR should be set to ${CI_PROJECT_DIR}

if [ -n "${BUILD_CACHE_DIR}" ]; then
# Set a local cache path for composer, so we can cache between builds and make things faster
  echo "Setting composer cache directory to ${BUILD_CACHE_DIR}/.composer-cache"
  /usr/local/bin/composer config -g cache-files-dir "${BUILD_CACHE_DIR}/.composer-cache"

	# Set a local cache path for npm, so we can cache between builds and make things faster
	# node_modules_cache was choosen since we already ignore *node_modules* in rsync-excludes
	echo "Setting npm cache directory to ${BUILD_CACHE_DIR}/node_modules_cache"
	npm config set cache "${BUILD_CACHE_DIR}/node_modules_cache" --global
fi

# Output versions of various installed packages
set -x
php --version
composer --version
node --version
npm --version
grunt --version
gulp --version
bower --version
yarn --version
wp --version --allow-root
set +x

exec "$@"
