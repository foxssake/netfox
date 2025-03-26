#!/bin/bash

# Assume we're running from project root
source sh/shared.sh

# Check Godot version
if ! godot --version | grep ^4.4; then
  print "Wrong Godot version!"
  godot --version
  exit 1;
fi

print "::group::Import project"
godot --headless --import .
print "::endgroup::"

UNTRACKED_FILES="$(git ls-files --others --exclude-standard)"
if [[ "$UNTRACKED_FILES" ]]; then
  print "Missing UIDs detected!"
  echo "$UNTRACKED_FILES"
  exit 1
else
  print "All UIDs are present!"
fi
