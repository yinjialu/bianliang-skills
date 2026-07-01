# bianliang-skills

当前版本：`0.1.1`

变量生活的内容生产 skills。按 [skills.sh](https://skills.sh/) 发布，`npx skills add yinjialu/bianliang-skills` 安装（Claude Code / Codex 通用）。

本仓库本身就是 skill 源仓库；在本仓开发时不要再对当前目录执行安装命令，否则会生成 `.agents/`、`skills-lock.json` 或 symlink 布局，干扰 git 追踪。

## skills

- **article-harness** —— 把带骨架的草稿经 Writer-Reviewer 迭代打磨成可发布文章（专注「成稿」）。
  内置 writer/reviewer 为**通用模板**；个人写作品味放本地 `~/Documents/context-harness-data/article-harness/{writer,reviewer}.md`，
  运行时优先加载（见 `harness.sh`），不随仓公开。Codex 内优先由 Codex subagent 编排；只有没有 Codex subagent 工具或显式从 shell 调用时，才落回 `harness.sh` 驱动 `claude -p`。

## 后续

review-wechat-layout、wechat-official-draft 将陆续收敛进本仓统一管理。

## release

用 semver 升级、推送远程 main、打 tag，并更新本机全局安装：

```bash
scripts/release.sh 0.1.1
```

release 脚本会使用 `npx skills` 更新/安装 `article-harness`，覆盖 Claude Code 和 Codex 的全局使用路径。
