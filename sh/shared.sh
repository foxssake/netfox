#!/bin/bash

# Formatting
# See: https://github.com/chalk/ansi-styles/blob/main/index.js
NC="\033[0m";
BOLD="\033[1m";

print() {
  echo -e $@
}

# Version and addon data for build
version="$(grep "version=" addons/netfox/plugin.cfg | cut -d"\"" -f2)"
addons=("netfox" "netfox.internals" "netfox.noray" "netfox.extras")

declare -A addon_deps=(\
  ["netfox"]="netfox.internals"
  ["netfox.noray"]="netfox.internals"
  ["netfox.extras"]="netfox.internals netfox"
)

# git config
if [[ "$(git config user.name)" == "" ]]; then
  print "Configuring git user"
  git config user.name "Fox's Sake CI"
  git config user.email "ci@foxssake.studio"
fi;

