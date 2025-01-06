#!/bin/bash

source sh/shared.sh

# Run tests
print $BOLD"Running tests..."$NC
godot --headless -q -s "res://addons/vest/vest-cli.gd" .

# Check results
if grep "not ok" vest.log; then
  print $BOLD"Test failed!"$NC
  cat vest.log
  exit 1
else
  print $BOLD"Success!"$NC
fi
