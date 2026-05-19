# Codex Memory Hub

这是一个让 Codex 工作可以跨新线程续接的记忆插件。

它现在采用“线程记忆”模型：每个 Codex 线程写自己的记忆文件，项目级文件只保留入口规则和稳定背景。这样同一个项目里开多个线程并行做 PPT、图片、代码或资料整理时，不会反复抢写同一个项目记忆文件。

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
docs/wiki/index.md
docs/wiki/project.md
docs/wiki/thread-memory/
```

新线程开始时，Codex 应该列出 `docs/wiki/thread-memory/` 里的全部线程记忆文件，让用户选择“新建一个线程记忆”或“复用某个已有线程记忆”。

并行任务建议新建不同的线程记忆文件；只有继续同一个工作流时才复用原文件。

## 记忆规则

线程记忆记录过程，项目文件只保存稳定背景。

默认不再维护 `current-status.md`、`next-actions.md`、`decisions.md`、`session-log.md` 这类公共状态页。用户明确要求“汇总项目记忆”或“整理所有线程”时，Codex 再从线程记忆里整理项目级总结。

## 包含内容

- `.codex-plugin/plugin.json`：插件元数据。
- `skill/codex-memory-hub/SKILL.md`：skill 使用规则。
- `skill/codex-memory-hub/scripts/`：skill 调用的跨平台项目初始化脚本。
- `LICENSE` 和 `CHANGELOG.md`：开源协议和版本记录。

## 边界

这个插件不会在后台监控所有新文件夹，也不会自动修改每个目录。只有在你确认或要求初始化项目记忆后，它才会创建这些文件。
