#!/bin/bash

version="$(grep "version=" addons/netfox/plugin.cfg | cut -d"\"" -f2)"
addons=("netfox" "netfox.internal" "netfox.noray" "netfox.extras")

declare -A addon_deps=(\
  ["netfox"]="netfox.internal"
  ["netfox.noray"]="netfox.internal"
  ["netfox.extras"]="netfox.internal netfox"
)
