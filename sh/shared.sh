#!/bin/bash

version="$(grep "version=" addons/netfox/plugin.cfg | cut -d"\"" -f2)"
addons=("netfox" "netfox.internals" "netfox.noray" "netfox.extras")

declare -A addon_deps=(\
  ["netfox"]="netfox.internals"
  ["netfox.noray"]="netfox.internals"
  ["netfox.extras"]="netfox.internals netfox"
)
