#!/usr/bin/env bash
# Parse-checks every GDScript file in the project with Godot's --check-only.
# Usage: tools/check_scripts.sh [godot-binary]   (run `godot --headless --import` once first)
set -u
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
failed=0
while IFS= read -r -d '' file; do
	res_path="res://${file#./}"
	output="$("$GODOT" --headless --path . --check-only --script "$res_path" 2>&1)"
	if echo "$output" | grep -qE "SCRIPT ERROR|Parse Error|ERROR:"; then
		echo "FAIL: $res_path"
		echo "$output" | grep -E "SCRIPT ERROR|Parse Error|ERROR:|at:" | head -8 | sed 's/^/    /'
		failed=$((failed + 1))
	fi
done < <(find . -path ./.godot -prune -o -name "*.gd" -print0)
if [ "$failed" -ne 0 ]; then
	echo "$failed script(s) failed to parse"
	exit 1
fi
echo "All scripts parsed cleanly."
