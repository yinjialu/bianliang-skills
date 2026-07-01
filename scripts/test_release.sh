#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"
SKILL_FILE="$ROOT/skills/article-harness/SKILL.md"
RELEASE_SCRIPT="$ROOT/scripts/release.sh"

[ -f "$VERSION_FILE" ] || { echo "FAIL: missing VERSION"; exit 1; }
[ -x "$RELEASE_SCRIPT" ] || { echo "FAIL: scripts/release.sh is not executable"; exit 1; }

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
grep -q "^version: ${VERSION}$" "$SKILL_FILE" || {
  echo "FAIL: SKILL.md version does not match VERSION"
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rsync -a --exclude .git "$ROOT/" "$TMP/repo/"
cd "$TMP/repo"

export RELEASE_COMMAND_LOG="$TMP/release.log"
export RELEASE_SKIP_FETCH=1
export RELEASE_TEST_MODE=1
export HOME="$TMP/home"
mkdir -p "$HOME"

bash scripts/release.sh 0.1.1

grep -q '^0.1.1$' VERSION || { echo "FAIL: VERSION was not updated"; exit 1; }
grep -q '当前版本：`0.1.1`' README.md || {
  echo "FAIL: README version was not updated"
  exit 1
}
grep -q '^version: 0.1.1$' skills/article-harness/SKILL.md || {
  echo "FAIL: SKILL.md version was not updated"
  exit 1
}
grep -q 'git commit -m chore(release): v0.1.1' "$RELEASE_COMMAND_LOG" || {
  echo "FAIL: release did not commit"
  exit 1
}
grep -q 'git tag -a v0.1.1 -m v0.1.1' "$RELEASE_COMMAND_LOG" || {
  echo "FAIL: release did not tag"
  exit 1
}
grep -q 'git push origin main' "$RELEASE_COMMAND_LOG" || {
  echo "FAIL: release did not push main"
  exit 1
}
grep -q 'git push origin v0.1.1' "$RELEASE_COMMAND_LOG" || {
  echo "FAIL: release did not push tag"
  exit 1
}
grep -q 'npx skills add yinjialu/bianliang-skills -g --skill article-harness --agent claude-code codex -y --copy' "$RELEASE_COMMAND_LOG" || {
  echo "FAIL: release did not install with npx skills for Claude Code and Codex"
  exit 1
}

echo "PASS release"
