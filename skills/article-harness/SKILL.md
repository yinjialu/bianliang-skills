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

## 执行流程

```bash
bash skills/article-harness/harness.sh <draft.md路径> [最大轮次]
```

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
