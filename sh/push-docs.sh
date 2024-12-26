#!/bin/bash

# Assume we're running from project root
source sh/shared.sh

# Grab commit history
print $BOLD"Unshallowing commit history"$NC
git fetch --unshallow --filter=tree:0

# Figure out version
TAG="$(git tag --points-at HEAD)"
REF="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"

VERSION="$SHA"
if [ "$REF" == "main" ]; then
  VERSION="latest";
elif [ "$TAG" != "" ]; then
  VERSION="$TAG";
fi;

# Push version
print -e "Pushing version $BOLD$VERSION$NC"
mike deploy --push "$VERSION"

