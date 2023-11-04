#!/bin/bash

version="$(grep "version=" addons/netfox/plugin.cfg | cut -d"\"" -f2)"

echo "Building netfox v${version}"
mkdir -p build

# Pack addons
echo "Packing netfox"
zip -r "build/netfox.v${version}.zip" "addons/netfox"

echo "Packing netfox.noray"
zip -r "build/netfox.noray.v${version}.zip" "addons/netfox.noray"

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
