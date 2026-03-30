#!/bin/bash

source sh/shared.sh

group "Ensuring dependencies"
(cd sh/refdoc && bun i)
endgroup

group "Importing project"
godot --headless --import .
endgroup

group "Dumping API docs"
mkdir -p apidocs
godot --doctool apidocs/ --no-docbase --gdscript-docs .
endgroup

group "Rendering reference pages"
bun sh/refdoc/ apidocs/ ./ docs/class-reference/
RESULT="$?"
endgroup

exit $RESULT
