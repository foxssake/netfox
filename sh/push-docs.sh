#!/bin/bash

BOLD="$(tput bold)"
NC="$(tput sgr0)"

# Assume we're running from project root
source sh/shared.sh

# Grab commit history
echo $BOLD"Unshallowing commit history"$NC
git fetch --unshallow --filter=tree:0

# Figure out version
TAG="$(git tag --points-at HEAD)"
SHA="$(git rev-parse --short HEAD)"

VERSION="$SHA"
if [ "$TAG" != "" ]; then
  VERSION="$TAG";
fi;

# Push version
echo "Pushing version $BOLD$VERSION$NC"
mike deploy --push "$VERSION"

