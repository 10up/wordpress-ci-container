#!/bin/bash

find . -type f -name '*.php' -not -path '*/vendor/*' -print0 | xargs -0 -n1 php -l
