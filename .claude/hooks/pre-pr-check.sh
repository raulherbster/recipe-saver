#!/bin/bash
# Runs all tests before allowing `gh pr create`.
# Exits 2 (block) if tests fail, 0 (allow) otherwise.

input=$(cat)
cmd=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if ! echo "$cmd" | grep -q "gh pr create"; then
  exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "🧪 Running tests before creating PR..." >&2
echo "" >&2

cd "$REPO_ROOT/mobile" && flutter test 2>&1 >&2
MOBILE_EXIT=$?

echo "" >&2
if [ $MOBILE_EXIT -ne 0 ]; then
  echo "❌ Tests failed. Fix them before creating a PR." >&2
  exit 2
fi

echo "✅ All tests passed." >&2
exit 0
