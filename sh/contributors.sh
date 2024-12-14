#!/bin/bash

# Outputs a contributors' notice


echo """# Contributors

This addon, and the entirety of [netfox] is a shared effort of [Fox's Sake
Studio], and the community. The following is the list of community contributors
involved with netfox:
"""

git log --pretty="* %an <%ae>%n%cn <%ce>" | sort -u \
  | grep -v "Tamás Gálffy" \
  | grep -v "<noreply.github.com>"

echo """
[netfox]: https://github.com/foxssake/netfox
[Fox's Sake Studio]: https://github.com/foxssake/
"""
