# Codex Memory Hub

给 Codex 用的项目记忆插件。

它解决一个问题：同一个项目开新线程、开多个线程、隔几天再回来时，Codex 还能接上之前的进度，而且不会把多个线程写到同一个记忆文件里。

## 它是什么

这是一个 **Codex plugin**，核心能力是里面的 skill：`codex-memory-hub`。

项目根目录只保留一个入口文件：

```text
AGENTS.md
```

所有记忆都放在：

```text
.codex-memory/
```

## 怎么用

在项目目录里对 Codex 说：

```text
给这个项目初始化 Codex 记忆。
```

以后正常说任务即可：

```text
继续这个项目。
继续做 PPT 图片。
帮我审计这次改动。
接着讨论首页设计。
```

用户不需要管记忆文件，也不需要知道 workstream 名称。

## 会创建什么

初始化后结构是：

```text
AGENTS.md
.codex-memory/
  index.md
  project.md
  threads/
  workstreams/
  archive/
```

每个文件夹的作用：

```text
index.md       记忆入口索引
project.md     项目稳定背景，不当实时进度
threads/       每个 Codex 线程自己的记忆
workstreams/   多个线程做同一件事时的归组
archive/       旧版记忆和归档内容
```

## 自动记忆规则

Codex 会自己判断“读哪里”和“写哪里”。

```text
旧 thread memory   只读，用来恢复上下文
新 thread memory   本轮线程的写入位置
continues_from     记录本轮继承了哪些旧 thread
workstream         把多个 thread 归到同一个任务
event              线程完成阶段时留下的短记录
snapshot           快速启动摘要，可从 thread/event 重建
```

最重要的规则：

```text
新 Codex 会话默认创建新的 thread memory。
旧 thread memory 默认只读。
只有用户明确说“复用这个 thread 文件”，才会继续写旧 thread。
```

## 常见场景

### 1. 新线程续写旧任务

链路：

```text
读取旧 thread
-> 创建新 thread
-> 在新 thread 写 continues_from
-> 关联同一个 workstream
-> 后续只写新 thread
```

示例：

```yaml
thread: continue-ppt-images
status: active
workstream: ppt-images
continues_from:
  - .codex-memory/threads/2026-05-24-0900-ppt-images.md
```

### 2. 多线程并发做同一个交付物

比如三四个线程同时做一套 PPT 图片：

```text
每个线程写自己的 thread memory
同一套 PPT 自动归到同一个 workstream
每个线程结束时写自己的 event
snapshot 保存当前简短进度
```

不会抢写同一个总状态文件。

### 3. 一个线程写代码，一个线程聊设计，一个线程审计

如果都围绕同一个功能：

```text
代码线程   -> 写代码进展
设计线程   -> 写设计决策
审计线程   -> 写问题和风险
workstream -> 把三条线程归到同一功能
```

如果主题不同，Codex 会自动分开。

## 旧版项目

如果项目里已经有旧版 `docs/wiki/` 记忆，初始化时会自动迁移：

```text
旧 thread-memory       -> .codex-memory/threads/
旧 current-status 等   -> 转成新版 thread memory
原 docs/wiki           -> .codex-memory/archive/
```

用户不需要手动搬文件。

## Git 和隐私

在 Git 项目中，`.codex-memory/` 默认加入 `.gitignore`。

这样可以避免把本地路径、提示词、决策过程或敏感细节意外提交。

记忆文件不应该保存：

```text
密钥
token
密码
私密资料原文
敏感凭证
```

如果你明确想让团队共享记忆，再手动调整 `.gitignore`，并先检查隐私内容。

## 边界

它不是后台守护进程，不会在你没打开 Codex 时自动整理所有项目。

它也不是数据库或全文知识库。

它适合保存 Codex 继续工作需要的摘要、进度、决策、产物位置、问题和下一步。
