#!/bin/bash

BOLD="$(tput bold)"
NC="$(tput sgr0)"

ROOT="$(pwd)"
BUILD="$ROOT/build"
TMP="$ROOT/buildtmp"

declare -a OFF_FILES=(
  "addons/netfox.extras/physics/godot_driver_2d.gd"
  "addons/netfox.extras/physics/godot_driver_2d.gd.uid"
  "addons/netfox.extras/physics/godot_driver_3d.gd"
  "addons/netfox.extras/physics/godot_driver_3d.gd.uid"
  "addons/netfox.extras/physics/rapier_driver_2d.gd"
  "addons/netfox.extras/physics/rapier_driver_2d.gd.uid"
  "addons/netfox.extras/physics/rapier_driver_3d.gd"
  "addons/netfox.extras/physics/rapier_driver_3d.gd.uid"
)

# Assume we're running from project root
source sh/shared.sh

# Grab commit history
print $BOLD"Unshallowing commit history"$NC
git fetch --unshallow --filter=tree:0

print $BOLD"Building netfox v${version}" $NC

print "Directories"
print "Root: $ROOT"
print "Build: $BUILD"
print "Temp: $TMP"

rm -rf "$BUILD"
mkdir -p "$BUILD"
rm -rf "$TMP"

# Disable scripts
print "::group::Disabling optional scripts"
has_missing_offs="false"

for file in "${OFF_FILES[@]}"; do
  has_source=$(test -f "$file" && echo "true" || echo "false")
  has_off=$(test -f "$file.off" && echo "true" || echo "false")

  if [[ $has_source == "false" && $has_off == "false" ]]; then
    print "::error::Registered optional script doesn't exist: $file"
    has_missing_offs="true"
  fi

  if [[ $has_source == "true" ]]; then
    mv "$file" "$file.off"
    print "Disabled optional script: $file"
  fi
done

if [[ $has_missing_offs == "true" ]]; then
  print "::error::Found missing optional scripts!"
  print "::endgroup::"
  exit 1;
fi;
print "::endgroup::"

# Bundle addons
for addon in ${addons[@]}; do
    print "::group::Packing addon ${addon}"

    addon_tmp="$TMP/${addon}.v${version}/addons"
    addon_src="$ROOT/addons/${addon}"
    addon_dst="$BUILD/${addon}.v${version}"

    mkdir -p "${addon_tmp}"
    cd "$TMP"

    cp -r "${addon_src}" "${addon_tmp}"
    "$ROOT/sh/contributors.sh" > "${addon_tmp}/${addon}/CONTRIBUTORS.md"

    has_deps="false"
    for dep in ${addon_deps[$addon]}; do
      print "Adding dependency $dep"
      cp -r "$ROOT/addons/${dep}" "${addon_tmp}"
      "$ROOT/sh/contributors.sh" > "${addon_tmp}/${dep}/CONTRIBUTORS.md"
      has_deps="true"
    done

    if [ $has_deps = "true" ]; then
      zip -r "${addon_dst}.zip" "${addon}.v${version}"
    fi

    cd "$ROOT"
    rm -rf "$TMP"
    print "::endgroup::"
done

# Build example game
print $BOLD"Building Forest Brawl" $NC
mkdir -p build/linux
mkdir -p build/win64

print "Building with Linux/X11 preset"
godot --headless --export-release "Linux/X11" "build/linux/forest-brawl.x86_64"
zip -j "build/forest-brawl.v${version}.linux.zip" build/linux/*

print "Building with Windows preset"
godot --headless --export-release "Windows Desktop" "build/win64/forest-brawl.exe"
zip -j "build/forest-brawl.v${version}.win64.zip" build/win64/*

# Build docs
print $BOLD"Building docs" $NC
mkdocs build --no-directory-urls
cd site
zip -r "../build/netfox.docs.v${version}.zip" ./*
cd ..
rm -rf site

# Cleanup
print $BOLD"Cleaning up" $NC
rm -rf build/win64 build/linux
