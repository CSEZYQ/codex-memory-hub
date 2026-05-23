# Codex Memory Hub

这是一个让 Codex 工作可以跨新线程续接的记忆插件。

它采用干净的项目结构：项目根目录只保留 `AGENTS.md`，所有记忆数据都放进 `.codex-memory/`。每个 Codex 线程写自己的记忆文件；多个线程协作同一件事时，用 workstream 记录共享进展，避免大家抢写同一个状态文件。

## 安装

通过 Codex 的插件或 skill 安装流程导入这个文件夹或仓库即可。

本项目不需要用户手动运行额外安装脚本。Codex 会通过下面的文件识别插件：

```text
.codex-plugin/plugin.json
```

并通过下面的文件识别 skill：

```text
skill/codex-memory-hub/SKILL.md
```

## 使用

安装后，在项目目录里可以直接说：

```text
给这个项目初始化 Codex 记忆。
```

初始化后会创建：

```text
AGENTS.md
.codex-memory/index.md
.codex-memory/project.md
.codex-memory/threads/
.codex-memory/workstreams/
.codex-memory/archive/
```

新线程开始时，Codex 会读取 `.codex-memory/`，列出已有线程记忆和相关 workstream，让用户选择新建或复用。

并行任务建议新建不同的线程记忆文件；如果多个线程处理同一个任务、功能或交付物，它们共享同一个 workstream，并通过独立事件文件记录进展。

## 记忆规则

线程记忆记录过程，workstream 记录协作进展，`project.md` 只保存稳定背景。

默认不再维护 `current-status.md`、`next-actions.md`、`decisions.md`、`session-log.md` 这类公共状态页。用户明确要求“汇总项目记忆”或“整理所有线程”时，Codex 再从 `.codex-memory/` 里整理项目级总结。

## 包含内容

- `.codex-plugin/plugin.json`：插件元数据。
- `skill/codex-memory-hub/SKILL.md`：skill 使用规则。
- `skill/codex-memory-hub/scripts/`：skill 调用的跨平台项目初始化脚本。
- `LICENSE` 和 `CHANGELOG.md`：开源协议和版本记录。

## 边界

这个插件不会在后台监控所有新文件夹，也不会自动修改每个目录。只有在你确认或要求初始化项目记忆后，它才会创建这些文件。
