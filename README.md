# Codex Memory Hub

这是一个让 Codex 工作可以跨新线程续接的记忆插件。

它采用干净的项目结构：项目根目录只保留 `AGENTS.md`，所有记忆数据都放进 `.codex-memory/`。每个 Codex 线程写自己的记忆文件；多个线程协作同一件事时，用 workstream 记录共享进展，避免大家抢写同一个状态文件。

## 安装

通过 Codex 的插件或 skill 安装流程导入这个文件夹或仓库即可。

Codex 会通过下面的文件识别插件：

```text
.codex-plugin/plugin.json
```

并通过下面的文件识别 skill：

```text
skill/codex-memory-hub/SKILL.md
```

## 第一次使用

在项目目录里对 Codex 说：

```text
给这个项目初始化 Codex 记忆。
```

Codex 会创建：

```text
AGENTS.md
.codex-memory/index.md
.codex-memory/project.md
.codex-memory/threads/
.codex-memory/workstreams/
.codex-memory/archive/
```

用户不需要手动创建这些文件，也不需要手动整理目录。

## 继续项目

在同一个项目里开新线程时，可以直接说：

```text
读取本项目记忆，继续。
```

Codex 会读取 `.codex-memory/`，列出已有线程记忆和相关 workstream，让你选择新建或复用。你已经明确指定某个任务或 workstream 时，Codex 可以直接接上。

## 旧版项目

如果项目里已经有旧版 `docs/wiki/` 记忆，可以直接说：

```text
使用 Codex Memory Hub 检查并整理本项目记忆。
```

Codex 会自动迁移到 `.codex-memory/`：

- 旧线程记忆会复制到 `.codex-memory/threads/`
- 最早公开版的 `current-status.md`、`next-actions.md`、`decisions.md`、`session-log.md` 等会转成新版 active 线程记忆
- 原始旧目录会归档到 `.codex-memory/archive/`
- 用户不需要手动搬文件

## 并行线程

同一个项目里可以开多个 Codex 线程。

建议这样说：

```text
为这个任务新建线程记忆，并加入 workstream: ppt-v1。
```

另一个线程可以说：

```text
读取 workstream: ppt-v1，创建新的线程记忆继续处理图片。
```

规则是：

- 每个线程写自己的 `.codex-memory/threads/*.md`
- 同一任务的多个线程共享一个 `.codex-memory/workstreams/<name>/`
- 每个线程用独立 event 文件记录进展，不抢写同一个状态文件

## 用户要不要管文件

正常不用管。

用户只需要告诉 Codex：

- 初始化本项目记忆
- 读取本项目记忆继续
- 检查并整理本项目记忆
- 使用或新建某个 workstream

Codex 负责创建、迁移、归档、写回和选择合适的记忆位置。

只有这些情况需要用户明确决定：

- 是否把 `.codex-memory/` 提交到 Git
- 是否团队共享项目记忆
- 多个 workstream 很相似时，到底复用哪个
- 语义冲突需要确认，比如两个线程给出相反方案

## Git 和隐私

在 Git 项目中，`.codex-memory/` 默认会加入 `.gitignore`，避免把本地记忆、路径、提示词或敏感项目细节意外提交。

如果你明确想让团队共享记忆，可以移除这条忽略规则，但要先确认里面没有隐私内容。

记忆文件不应该保存密钥、token、密码、私密资料原文或敏感凭证。

## 边界

这个插件不会在后台监控所有新文件夹，也不会自动修改每个目录。只有在你确认或要求初始化、整理、继续项目记忆时，它才会工作。

它不是数据库，也不是全文知识库。它适合保存 Codex 继续工作需要的摘要、进度、决策、产物位置、问题和下一步。
