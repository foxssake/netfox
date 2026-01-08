#!/bin/bash

source sh/shared.sh
VEST_LOG="vest.log"

# Run tests
# NOTE: Must be ran with 4.2+, so the --import flag is available
# Otherwise, Godot won't import scripts properly
print "::group::Import project"
godot --headless --import .
print "::endgroup::"

print "::group::Run vest"
godot --headless -s "addons/vest/cli/vest-cli.gd" \
      --vest-glob "res://test/*.test.gd" \
      --vest-report-format tap --vest-report-file "$VEST_LOG"
print "::endgroup::"

# Check results
if [ ! -f "$VEST_LOG" ]; then
  echo "::error::No test logs!"
  exit 1
fi

echo "::group::Test report"
cat "$VEST_LOG"
echo ""
echo "::endgroup::"

if grep "not ok" "$VEST_LOG"; then
  echo "::error::There are failing test(s)!"
  exit 1
else
  print "Success!"
fi
