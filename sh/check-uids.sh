#!/bin/bash

# Assume we're running from project root
source sh/shared.sh

# Check Godot version
if ! godot --version | grep ^4.4; then
  print "Wrong Godot version!"
  godot --version
  # exit 1;
fi

godot --headless --import .
if [[ $(git ls-files --others --exclude-standard) ]]; then
  print "Import produced new files!"
  git ls-files --others --exclude-standard
  exit 1
fi
