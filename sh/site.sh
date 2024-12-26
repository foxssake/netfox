#!/bin/bash

BOLD="$(tput bold)"
NC="$(tput sgr0)"

ROOT="$(pwd)"
BUILD="$ROOT/build"
TMP="$ROOT/buildtmp"

# Assume we're running from project root
source sh/shared.sh

echo $BOLD"Building netfox documentation"$NC

# Grab commit history
echo $BOLD"Unshallowing commit history"$NC
git fetch --unshallow --filter=tree:0

HEAD="$(git rev-parse --abbrev-ref HEAD)"

# Gather versions
VERSIONS="$(git tag | grep "^v") latest"
VERSIONS="$(echo $VERSIONS | tr '\n' ' ')"
# echo "Found versions: $VERSIONS"

# Prepare workplace
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Build versions
for VERSION in $VERSIONS; do
  echo "Building version $BOLD$VERSION$NC..."
  VERDIR="$BUILD/$VERSION"
  mkdir -p "$VERDIR"

  if [ $VERSION == 'latest' ]; then
    git checkout main
  else
    git checkout $VERSION
  fi;
  mkdocs build -d "$VERDIR"
done

# Cleanup
echo "Restoring HEAD"
git checkout "$HEAD"
