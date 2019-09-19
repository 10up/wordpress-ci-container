#!/bin/sh

echo "$PRIVATE_KEY" > /root/.ssh/id_rsa
echo "$PUBLIC_KEY" > /root/.ssh/id_rsa.pub
chmod 600 /root/.ssh/id_rsa

if [ -z ${TERMINUS_TOKEN+x} ]; then
	echo "TERMINUS_TOKEN is not set, skipping terminus setup.";
else
	echo "TERMINUS_TOKEN is set. Logging In.";
	terminus auth:login --machine-token="$TERMINUS_TOKEN"
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
set +x

exec "$@"
