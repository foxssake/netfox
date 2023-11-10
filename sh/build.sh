#!/bin/bash

BOLD="$(tput bold)"
NC="$(tput sgr0)"

make_tag=false

while (( "$#" )); do
  if [[ "$1" == "--tag" ]]; then
    echo "Will create tag"
    make_tag=true
  fi

  shift
done

# Assume we're running from project root
source sh/shared.sh

echo $BOLD"Building netfox v${version}" $NC
mkdir -p build

for addon in ${addons[@]}; do
    echo "Packing addon ${addon}"
    zip -r "build/${addon}.v${version}.zip" "addons/${addon}"

    if [ "$addon" != "netfox" ]; then
      zip -r "build/${addon}.with-deps.v${version}.zip" "addons/${addon}" "addons/netfox"
    fi
done

# Build example game
echo $BOLD"Building Forest Brawlers" $NC
mkdir -p build/linux
mkdir -p build/win64

echo "Building with Linux/X11 preset"
godot --headless --export-release "Linux/X11" "build/linux/forest-brawlers.x86_64"
zip -j "build/forest-brawlers.v${version}.linux.zip" build/linux/*

echo "Building with Windows preset"
godot --headless --export-release "Windows Desktop" "build/win64/forest-brawlers.exe"
zip -j "build/forest-brawlers.v${version}.win64.zip" build/win64/*

# Tag release
if [ "$make_tag" = true ]; then
  echo $BOLD"Tagging as v$version"$NC
  git tag -a "v$version" -m "v$version"
  git push --tags
fi

# Cleanup
echo $BOLD"Cleaning up" $NC
rm -rf build/win64 build/linux
