#!/bin/bash

# Assume we're running from project root
source sh/shared.sh

echo "Building netfox v${version}"
mkdir -p build

for addon in ${addons[@]}; do
    echo "Packing addon ${addon}"
    zip -r "build/${addon}.v${version}.zip" "addons/${addon}"
done

# Build example game
echo "Building Forest Brawlers"
mkdir -p build/linux
mkdir -p build/win64

echo "Building with Linux/X11 preset"
godot --headless --export-release "Linux/X11" "build/linux/forest-brawlers.x86_64"
zip -j "build/forest-brawlers.v${version}.linux.zip" build/linux/*

echo "Building with Windows preset"
godot --headless --export-release "Windows Desktop" "build/win64/forest-brawlers.exe"
zip -j "build/forest-brawlers.v${version}.win64.zip" build/win64/*

# Cleanup
echo "Cleaning up"
rm -rf build/win64 build/linux
