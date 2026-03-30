#!/bin/bash

source sh/shared.sh

group "Ensuring dependencies"
(cd sh/refdoc && bun i)
endgroup

if [ -z "${NOIMPORT+x}" ]; then
  group "Importing project"
  godot --headless --import .
  endgroup
fi;

if [ -z "${NODUMP+x}" ]; then
  group "Dumping API docs"
  mkdir -p apidocs
  godot --doctool apidocs/ --no-docbase --gdscript-docs .
  endgroup
fi;

group "Rendering reference pages"
bun sh/refdoc/ apidocs/ ./ docs/class-reference/
RESULT="$?"
endgroup

exit $RESULT
