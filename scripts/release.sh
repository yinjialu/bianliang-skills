#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: scripts/release.sh <version>"
  echo "Example: scripts/release.sh 0.1.1"
}

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  usage
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $VERSION"
  echo "Use semver, for example: 0.1.1"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GIT_BIN="${GIT_BIN:-git}"
NPX_BIN="${NPX_BIN:-npx}"

log_command() {
  if [ -n "${RELEASE_COMMAND_LOG:-}" ]; then
    echo "$*" >> "$RELEASE_COMMAND_LOG"
  fi
}

git_cmd() {
  log_command "git $*"
  if [ -n "${RELEASE_TEST_MODE:-}" ]; then
    case "$1" in
      branch)
        if [ "${2:-}" = "--show-current" ]; then
          echo "main"
          return 0
        fi
        ;;
      rev-parse)
        return 1
        ;;
      rev-list)
        echo "0	0"
        return 0
        ;;
      fetch|diff|add|commit|tag|push)
        return 0
        ;;
    esac
    echo "unexpected git command in RELEASE_TEST_MODE: $*" >&2
    return 1
  fi
  "$GIT_BIN" "$@"
}

npx_cmd() {
  log_command "npx $*"
  if [ -n "${RELEASE_TEST_MODE:-}" ]; then
    return 0
  fi
  "$NPX_BIN" "$@"
}

BRANCH="$(git_cmd branch --show-current)"
if [ "$BRANCH" != "main" ]; then
  echo "Release must run from main; current branch is $BRANCH"
  exit 1
fi

if git_cmd rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists"
  exit 1
fi

if [ -z "${RELEASE_SKIP_FETCH:-}" ]; then
  git_cmd fetch origin
  COUNTS="$(git_cmd rev-list --left-right --count origin/main...HEAD)"
  BEHIND="${COUNTS%%	*}"
  if [ "$BEHIND" != "0" ]; then
    echo "Local main is behind origin/main; pull/rebase before release"
    exit 1
  fi
fi

echo "$VERSION" > VERSION

README_FILE="README.md"
TMP_FILE="$(mktemp)"
awk -v version="$VERSION" '
  /^当前版本：`/ {
    print "当前版本：`" version "`"
    next
  }
  { print }
' "$README_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$README_FILE"

SKILL_FILE="skills/article-harness/SKILL.md"
TMP_FILE="$(mktemp)"
awk -v version="$VERSION" '
  BEGIN { in_frontmatter = 0; wrote_version = 0 }
  NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
  in_frontmatter && /^version:/ {
    print "version: " version
    wrote_version = 1
    next
  }
  in_frontmatter && $0 == "---" {
    if (!wrote_version) {
      print "version: " version
      wrote_version = 1
    }
    print
    in_frontmatter = 0
    next
  }
  { print }
' "$SKILL_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$SKILL_FILE"

bash skills/article-harness/test_override.sh
git_cmd diff --check

git_cmd add -A
git_cmd commit -m "chore(release): v$VERSION"
git_cmd tag -a "v$VERSION" -m "v$VERSION"
git_cmd push origin main
git_cmd push origin "v$VERSION"

if [ -d "$HOME/.agents/skills/article-harness" ] || [ -d "$HOME/.codex/skills/article-harness" ]; then
  npx_cmd skills update article-harness -g -y
else
  npx_cmd skills add yinjialu/bianliang-skills -g --skill article-harness --agent claude-code codex -y --copy
fi

if [ -d "$HOME/.codex/skills" ] && [ -d "$HOME/.agents/skills/article-harness" ]; then
  mkdir -p "$HOME/.codex/skills/article-harness"
  rsync -a --delete "$HOME/.agents/skills/article-harness/" "$HOME/.codex/skills/article-harness/"
fi

echo "Released v$VERSION"
