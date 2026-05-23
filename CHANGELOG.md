# 更新记录

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
