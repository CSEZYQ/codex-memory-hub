# Codex Memory Hub

这是一个让 Codex 项目可以跨新线程续接的记忆插件。

它会在项目里建立一套轻量级记忆文件，用来保存项目目标、当前状态、下一步、关键决定、想法和会话记录。这样重新打开 Codex 时，它可以先读项目记忆，再继续工作，而不是只依赖当前聊天上下文。

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

安装后，不需要用户手动运行脚本：如果当前项目还没有 `AGENTS.md` 和 `docs/wiki`，Codex 会提醒你是否初始化项目记忆；如果项目已经有记忆，新线程会自动读取这些文件并继续上次进度。

你也可以直接说：

```text
给这个项目初始化 Codex 记忆。
```

初始化后会创建：

```text
AGENTS.md
docs/wiki/index.md
docs/wiki/project-overview.md
docs/wiki/current-status.md
docs/wiki/next-actions.md
docs/wiki/decisions.md
docs/wiki/session-log.md
docs/wiki/ideas.md
docs/wiki/log.md
```

## 包含内容

- `.codex-plugin/plugin.json`：插件元数据。
- `skill/codex-memory-hub/SKILL.md`：skill 使用规则。
- `skill/codex-memory-hub/scripts/`：skill 调用的跨平台项目初始化脚本。
- `LICENSE` 和 `CHANGELOG.md`：开源协议和版本记录。

## 边界

这个插件不会在后台监控所有新文件夹，也不会自动修改每个目录。只有在你确认或要求初始化项目记忆后，它才会创建这些文件。
