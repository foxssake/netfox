#!/bin/bash

source sh/shared.sh
VEST_LOG="vest.log"

# Run tests
# NOTE: Must be ran with 4.2+, so the --import flag is available
# Otherwise, Godot won't import scripts properly
group "Import project"
godot --headless --import .
endgroup

group "Run vest"
godot --headless -s "addons/vest/cli/vest-cli.gd" \
      --vest-glob "res://test/*.test.gd" \
      --vest-report-format tap --vest-report-file "$VEST_LOG"
endgroup

# Check results
if [ ! -f "$VEST_LOG" ]; then
  error "No test logs!"
  exit 1
fi

group "Test report"
cat "$VEST_LOG"
echo ""
endgroup

if grep "not ok" "$VEST_LOG"; then
  error "There are failing test(s)!"
  exit 1
else
  print "Success!"
fi
