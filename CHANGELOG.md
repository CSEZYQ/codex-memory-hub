# 更新记录

## 1.3.2 - 2026-05-24

- 重写 README 使用说明，明确初始化、继续项目、旧版迁移、并行线程、Git 隐私和用户是否需要手动管理文件等场景。

## 1.3.1 - 2026-05-24

- 增强最早公开版兼容：将 `project-overview.md`、`current-status.md`、`next-actions.md`、`decisions.md`、`session-log.md`、`ideas.md` 和 `log.md` 自动转成新版 active 线程记忆。
- 升级后旧项目不只归档旧文件，也会把可继续工作的旧项目记忆放入 `.codex-memory/threads/`。

## 1.3.0 - 2026-05-24

- 新增旧版 `docs/wiki/` 自动迁移：线程记忆复制到 `.codex-memory/threads/`，旧目录归档到 `.codex-memory/archive/`。
- Git 项目初始化时默认将 `.codex-memory/` 加入 `.gitignore`，避免意外提交本地记忆。
- 增加隐私规则：记忆文件不得保存密钥、token、密码、敏感凭证或私密资料原文。
- 增加 workstream 复用和重复归档规则，减少并行任务下重复创建协作流。

## 1.2.0 - 2026-05-24

- 采用 `.codex-memory/` 作为统一记忆目录，保持项目根目录干净。
- 新增 workstream 协作层，用于同一任务下多个线程共享进展。
- 初始化结构调整为 `AGENTS.md`、`.codex-memory/index.md`、`.codex-memory/project.md`、`.codex-memory/threads/`、`.codex-memory/workstreams/` 和 `.codex-memory/archive/`。
- 保留对旧 `docs/wiki` 结构的读取兼容，但新记忆默认写入 `.codex-memory/`。

## 1.1.0 - 2026-05-19

- 改为线程记忆模型：每个 Codex 线程默认维护自己的记忆文件。
- 新线程启动时列出全部线程记忆，让用户选择新建或复用。
- 项目级记忆降级为可选稳定背景，不再默认维护公共状态页。
- 初始化结构精简为 `AGENTS.md`、`docs/wiki/index.md`、`docs/wiki/project.md` 和 `docs/wiki/thread-memory/`。

## 1.0.0 - 2026-05-12

- 首次公开发布。
- 提供 Codex 项目记忆初始化能力。
- 支持生成项目级 `AGENTS.md` 和 `docs/wiki` 记忆结构。
