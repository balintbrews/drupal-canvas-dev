#!/bin/bash

# The repository root composer.json runs this hook before composer install.
# The Mercury theme is not part of the Hazelnut environment, so this is a
# no-op that exists to keep composer.json byte-identical to the root copy.
exit 0
