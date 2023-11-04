#!/bin/bash

version="$(grep "version=" addons/netfox/plugin.cfg | cut -d"\"" -f2)"
addons=("netfox" "netfox.noray" "netfox.extras")
