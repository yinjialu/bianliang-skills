#!/bin/bash
# article-harness: Writer-Reviewer 迭代循环
# 用法: bash harness.sh <draft.md路径> [最大轮次=5]
# sources 字段（conversation + article）在 draft.md frontmatter 中自管理

set -euo pipefail

DRAFT="${1:?用法: harness.sh <draft.md路径> [最大轮次]}"
MAX_ITER="${2:-5}"
THRESHOLD=7
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CONVERSATIONS_DIR="/Users/jialu/Documents/context-harness-data/conversations"

DRAFT=$(realpath "$DRAFT")
WORKSPACE="$(dirname "$DRAFT")/.harness-workspace"
mkdir -p "$WORKSPACE"

FINISHED="$WORKSPACE/finished.md"
FEEDBACK="$WORKSPACE/feedback.md"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 草稿：$DRAFT"
echo "🔄 最大轮次：$MAX_ITER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 个人写作品味优先：本地存在则用本地，否则退仓内通用模板
LOCAL_DIR="${ARTICLE_HARNESS_LOCAL:-$HOME/Documents/context-harness-data/article-harness}"
WRITER_MD="$SKILL_DIR/writer.md";     [ -f "$LOCAL_DIR/writer.md" ]   && WRITER_MD="$LOCAL_DIR/writer.md"
REVIEWER_MD="$SKILL_DIR/reviewer.md"; [ -f "$LOCAL_DIR/reviewer.md" ] && REVIEWER_MD="$LOCAL_DIR/reviewer.md"
if [ -n "${HARNESS_DEBUG_PATHS:-}" ]; then
  echo "writer: $WRITER_MD"; echo "reviewer: $REVIEWER_MD"; exit 0
fi
WRITER_SYSTEM=$(cat "$WRITER_MD")
REVIEWER_SYSTEM=$(cat "$REVIEWER_MD")

for i in $(seq 1 "$MAX_ITER"); do
  echo ""
  echo "=== 第 $i 轮 ==="

  # ── Writer ──────────────────────────────────────────
  echo "✍️  Writer 运行中..."

  FEEDBACK_NOTE=""
  if [ -f "$FEEDBACK" ]; then
    FEEDBACK_NOTE="上轮 Reviewer 反馈见：${FEEDBACK}，请针对每个失败维度逐一改进。"
  else
    FEEDBACK_NOTE="首轮，无上轮反馈。"
  fi

  claude -p "$(cat <<EOF
$WRITER_SYSTEM

## 输入
- 原始草稿：${DRAFT}（frontmatter 中 sources 字段含素材来源和已有专文边界，请优先读取）
- 本地对话记录根目录：$CONVERSATIONS_DIR
- 输出路径：$FINISHED
- $FEEDBACK_NOTE
EOF
  )" \
    --allowedTools "Read,Write,Grep,Glob,WebSearch,WebFetch,Bash" \
    --output-format text \
    > "$WORKSPACE/writer_log_$i.txt" 2>&1

  if [ ! -f "$FINISHED" ]; then
    echo "❌ Writer 未产出 finished.md，查看日志：$WORKSPACE/writer_log_$i.txt"
    exit 1
  fi
  echo "   ✓ finished.md 已生成"

  # ── Reviewer ────────────────────────────────────────
  echo "🔍 Reviewer 运行中..."

  claude -p "$(cat <<EOF
$REVIEWER_SYSTEM

## 输入
- 待评估文章：$FINISHED
- 原始草稿（参考）：$DRAFT
- 反馈输出路径：$FEEDBACK
EOF
  )" \
    --allowedTools "Read,Write,WebSearch,WebFetch" \
    --output-format text \
    > "$WORKSPACE/reviewer_log_$i.txt" 2>&1

  if [ ! -f "$FEEDBACK" ]; then
    echo "❌ Reviewer 未产出 feedback.md，查看日志：$WORKSPACE/reviewer_log_$i.txt"
    exit 1
  fi

  # ── 检查结果 ─────────────────────────────────────────
  VERDICT=$(grep "^VERDICT:" "$FEEDBACK" | tail -1 || echo "VERDICT: UNKNOWN")
  echo "   判定：$VERDICT"

  if echo "$VERDICT" | grep -q "PASS"; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ PASS — 共 $i 轮"
    echo "📄 成稿：$FINISHED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # 打印评分摘要
    grep -A 10 "## 评分" "$FEEDBACK" | head -12 || true
    exit 0
  fi

  # FAIL：打印失败维度
  FAIL_LINE=$(grep "^失败维度" "$FEEDBACK" || echo "（未指定失败维度）")
  echo "   $FAIL_LINE"

  if [ "$i" -eq "$MAX_ITER" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  已达最大轮次 ${MAX_ITER}，未通过"
    echo "📄 最终稿（供参考）：$FINISHED"
    echo "📋 最后一轮反馈：$FEEDBACK"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
  fi
done
