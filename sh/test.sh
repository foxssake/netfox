#!/bin/bash

source sh/shared.sh
VEST_LOG="vest.log"

# Run tests
print $BOLD"Running tests..."$NC
godot --headless -q -s "res://addons/vest/vest-cli.gd" .

# Check results
if [ ! -f "$VEST_LOG" ]; then
  print $BOLD"No test logs!"$NC
  exit 1
fi

if grep "not ok" "$VEST_LOG"; then
  print $BOLD"Test failed!"$NC
  cat "$VEST_LOG"
  exit 1
else
  print $BOLD"Success!"$NC
fi
