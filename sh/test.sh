#!/bin/bash

source sh/shared.sh
VEST_LOG="vest.log"
VEST_OUT="$(mktemp)"

# Run tests
# NOTE: Must be ran with 4.2+, so the --import flag is available
# Otherwise, Godot won't import scripts properly
group "Import project"
godot --headless --import .
endgroup

group "Run vest"
godot --headless -s "addons/vest/cli/vest-cli.gd" \
      --vest-glob "res://test/*.test.gd" \
      --vest-report-format tap --vest-report-file "$VEST_LOG" 2>&1 | tee "$VEST_OUT"
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
fi

# VEST skips test files that fail to load, without reporting them
if grep -E "Parse Error|Compile Error|Failed to load script" "$VEST_OUT"; then
  error "There are scripts that failed to load!"
  exit 1
fi

suite_count="$(grep -cE "^(not )?ok " "$VEST_LOG")"
file_count="$(find test -name "*.test.gd" | grep -c .)"
if [[ $suite_count -ne $file_count ]]; then
  error "Ran $suite_count test suites, but found $file_count test files!"
  exit 1
fi

print "Success!"
