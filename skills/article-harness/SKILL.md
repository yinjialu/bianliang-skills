---
name: article-harness
description: 将带骨架的草稿通过 Writer-Reviewer 迭代循环打磨为可发布文章。当用户说"打磨文章"、"迭代草稿"、"article harness"、"跑 harness"时触发。
---

# article-harness

对一篇有骨架和待补充项的草稿，运行 Writer-Reviewer 迭代循环，自动完成打磨，输出可供最终人工 review 的成稿。

## 使用方式

```
/article-harness <draft.md路径> [最大轮次]
```

- `最大轮次`：可选，默认 5 轮

## 平台执行模型

article-harness 是同一套 Writer/Reviewer 协议在不同 Agent 宿主中的实现：

- **Codex 内使用时**：优先由当前 Codex 主 Agent 编排 Codex subagent。不要从 shell 里调用 `claude -p`，也不要在本仓库重复安装 `yinjialu/bianliang-skills`。
- **Claude Code 内使用时**：使用 `bash skills/article-harness/harness.sh <draft.md路径> [最大轮次]`，由脚本通过 `claude -p` 启动 Writer/Reviewer 子进程。
- **fallback 条件**：只有当前 Codex 会话没有 subagent 工具，或用户显式从 shell 调用时，才落回 `harness.sh`。

### Codex subagent 流程

当当前 Codex 会话暴露 subagent 能力（如 `multi_agent_v1.spawn_agent` / `wait_agent`）时，主 Agent 作为 controller 执行循环：

1. 创建 `.harness-workspace/`，确定：
   - `finished.md`：Writer 输出路径
   - `feedback.md`：Reviewer 输出路径
   - `writer_log_N.txt` / `reviewer_log_N.txt`：如当前宿主能记录日志，则保留每轮摘要
2. 每轮启动 Writer subagent：
   - 输入 `writer.md` 的角色 prompt
   - 输入原始草稿路径、本地对话记录根目录、输出路径、上轮反馈路径（如有）
   - 硬契约：必须写入 `.harness-workspace/finished.md`
3. Writer 完成后，主 Agent 检查 `finished.md` 是否存在；不存在则停止并报告该轮失败。
4. 启动 Reviewer subagent：
   - 输入 `reviewer.md` 的角色 prompt
   - 输入待评估文章路径、原始草稿路径、反馈输出路径
   - 硬契约：必须写入 `.harness-workspace/feedback.md`，最后一行必须是 `VERDICT: PASS` 或 `VERDICT: FAIL`
5. 主 Agent 读取 `feedback.md` 的 `VERDICT`：
   - `PASS`：停止循环，返回成稿路径
   - `FAIL`：进入下一轮，Writer 必须逐项处理反馈
   - 达到最大轮次仍失败：返回最终稿和最后反馈路径

Codex 模式的核心不是执行 `harness.sh`，而是复用同一组 prompt 和文件契约，用 Codex 原生 subagent 完成 Writer/Reviewer 迭代。

如果当前 Codex 会话没有暴露 subagent 工具，主 Agent 应说明能力缺失，并 fallback 到 Claude Code CLI 流程。

### Claude Code CLI 流程

```bash
bash skills/article-harness/harness.sh <draft.md路径> [最大轮次]
```

`harness.sh` 是 Claude Code CLI runner，保留 `claude -p` 和 Claude Code 的 `--allowedTools` 参数。

### Writer Agent（每轮）
1. 读取草稿 + 上轮 Reviewer 反馈（如有）
2. 搜索本地对话记录提炼作者第一手素材
3. 联网查证和补充缺失内容
4. 输出完整文章到 `.harness-workspace/finished.md`

### Reviewer Agent（每轮）
按 5 个维度评分（阈值均为 7 分）：
- **论点深度**：有推导链，不只是结论
- **素材真实性**：案例可查证，无虚构
- **结构节奏**：流畅递进，不堆砌
- **个人辨识度**：作者声音清晰，非泛泛 AI 腔
- **读者 takeaway**：看完能带走具体认知或行动

任何维度低于 7 分 → FAIL，反馈写入 `.harness-workspace/feedback.md`，Writer 继续迭代。
全部 ≥7 分 → PASS，输出成稿路径。

## 产物

| 文件 | 说明 |
|------|------|
| `.harness-workspace/finished.md` | 最终成稿，PASS 后交给你做最终 review |
| `.harness-workspace/feedback.md` | 最后一轮 Reviewer 评分和建议 |
| `.harness-workspace/writer_log_N.txt` | 第 N 轮 Writer 运行日志 |
| `.harness-workspace/reviewer_log_N.txt` | 第 N 轮 Reviewer 运行日志 |

## 后续链路

成稿通过人工最终 review 后，直接接 publish-wechat：

```
/publish-wechat .harness-workspace/finished.md --review
```
