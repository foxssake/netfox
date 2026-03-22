#!/bin/bash

source sh/shared.sh

MODE="lint"
FILES="$(find addons/netfox* examples -name '*.gd')"
RESULT="ok"

# Fix first if required
if [[ $1 == "--fix" ]]; then
  for file in $FILES; do
    echo "Fixing $file";
  done;
fi;

# Lint files
for file in $FILES; do
  # Check for trailing spaces
  if grep "[[:blank:]]\+$" "$file" > /dev/null; then
    error_in_file "$file" "Found trailing spaces!"
    RESULT="fail"
  fi
done;

if [[ $RESULT != "ok" ]]; then
  echo "Linting errors found!"
  echo "Run $0 --fix to fix errors"
  exit 1
fi
