#!/bin/bash

BOLD="$(tput bold)"
NC="$(tput sgr0)"

ROOT="$(pwd)"
BUILD="$ROOT/build"
TMP="$ROOT/buildtmp"

# Assume we're running from project root
source sh/shared.sh

echo $BOLD"Building netfox v${version}" $NC

echo "Directories"
echo "Root: $ROOT"
echo "Build: $BUILD"
echo "Temp: $TMP"

rm -rf "$BUILD"
mkdir -p "$BUILD"
rm -rf "$TMP"

for addon in ${addons[@]}; do
    echo "Packing addon ${addon}"

    addon_tmp="$TMP/${addon}.v${version}/addons"
    addon_src="$ROOT/addons/${addon}"
    addon_dst="$BUILD/${addon}.v${version}"

    mkdir -p "${addon_tmp}"
    cd "$TMP"

    cp -r "${addon_src}" "${addon_tmp}"

    has_deps="false"
    for dep in ${addon_deps[$addon]}; do
      echo "Adding dependency $dep"
      cp -r "$ROOT/addons/${dep}" "${addon_tmp}"
      has_deps="true"
    done

    if [ $has_deps = "true" ]; then
      zip -r "${addon_dst}.zip" "${addon}.v${version}"
    fi

    cd "$ROOT"
    rm -rf "$TMP"
done

# Build example game
echo $BOLD"Building Forest Brawl" $NC
mkdir -p build/linux
mkdir -p build/win64

echo "Building with Linux/X11 preset"
godot --headless --export-release "Linux/X11" "build/linux/forest-brawl.x86_64"
zip -j "build/forest-brawl.v${version}.linux.zip" build/linux/*

echo "Building with Windows preset"
godot --headless --export-release "Windows Desktop" "build/win64/forest-brawl.exe"
zip -j "build/forest-brawl.v${version}.win64.zip" build/win64/*

# Cleanup
echo $BOLD"Cleaning up" $NC
rm -rf build/win64 build/linux
