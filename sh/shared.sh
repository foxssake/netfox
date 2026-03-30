#!/bin/bash

# Formatting
# See: https://github.com/chalk/ansi-styles/blob/main/index.js
NC="\033[0m";
BOLD="\033[1m";
RED="\033[31m";

# Environment
IS_CI="no"
if [[ $GITHUB_ACTIONS != "" ]]; then IS_CI="yes"; fi

_PREFIX=""

print() {
  echo -e "$_PREFIX$@"
}

group() {
  if [[ $IS_CI == "yes" ]]; then
    echo "::group::$@"
  else
    print "› $@"
    _PREFIX="$_PREFIX  "
  fi
}

endgroup() {
  if [[ $IS_CI == "yes" ]]; then
    echo "::endgroup::"
  else
    _PREFIX="${_PREFIX::${#_PREFIX}-4}"
  fi
}

error() {
  if [[ $IS_CI == "yes" ]]; then
    print "::error::$@"
  else
    print "[${RED}error${NC}]: $@"
  fi
}

error_in_file() {
  FILE="$1"
  shift

  if [[ $IS_CI == "yes" ]]; then
    print "::error file=$FILE::$@"
  else
    print "[${RED}error${NC}]($FILE): $@"
  fi
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

