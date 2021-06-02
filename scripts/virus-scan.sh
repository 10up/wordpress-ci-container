#!/bin/bash

# Use ClamAV to do a virus scan of the repo. Only display files where a virus is
# found

# Colors
end="\033[0m"
red="\033[0;31m"
green="\033[0;32m"

function red {
  echo -e "${red}${1}${end}"
}

function green {
  echo -e "${green}${1}${end}"
}

green "#### Starting Virus Scan ####"

clamscan --exclude-dir ./.composer-cache --exclude-dir ./node_modules_cache -riz .

virus_status=$?

echo "-------"
echo ""

if [ $virus_status -eq 0 ]
then
  green "Clean - no viruses found"
  echo ""
  exit 0
elif [ $virus_status -eq 1 ]
then
  red "**** INFECTED FILE FOUND!!! **** PLEASE SEE REPORT ABOVE ****"
  echo ""
  exit 1
else
  red "Virus scanner internal error."
  echo ""
  exit 0 # don't block a deploy because the virus scan program is broken
fi
