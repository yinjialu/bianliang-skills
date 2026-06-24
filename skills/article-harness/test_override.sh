#!/bin/bash
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)/harness.sh"
TMP=$(mktemp -d)
mkdir -p "$TMP/local"
echo "draft" > "$TMP/draft.md"
echo "LOCAL-W" > "$TMP/local/writer.md"
echo "LOCAL-R" > "$TMP/local/reviewer.md"

# 1) 本地存在 → 用本地
OUT=$(ARTICLE_HARNESS_LOCAL="$TMP/local" HARNESS_DEBUG_PATHS=1 bash "$H" "$TMP/draft.md" 2>&1)
echo "$OUT" | grep -q "writer: $TMP/local/writer.md" || { echo "FAIL: 未优先本地 writer"; exit 1; }
echo "$OUT" | grep -q "reviewer: $TMP/local/reviewer.md" || { echo "FAIL: 未优先本地 reviewer"; exit 1; }

# 2) 本地不存在 → 退模板(仓内)
OUT2=$(ARTICLE_HARNESS_LOCAL="$TMP/none" HARNESS_DEBUG_PATHS=1 bash "$H" "$TMP/draft.md" 2>&1)
echo "$OUT2" | grep -q "writer: $(dirname "$H")/writer.md" || { echo "FAIL: 未退模板 writer"; exit 1; }

echo "PASS override"
rm -rf "$TMP"
