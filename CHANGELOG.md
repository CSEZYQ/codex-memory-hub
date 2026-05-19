# 更新记录

## 1.1.0 - 2026-05-19

- 改为线程记忆模型：每个 Codex 线程默认维护自己的记忆文件。
- 新线程启动时列出全部线程记忆，让用户选择新建或复用。
- 项目级记忆降级为可选稳定背景，不再默认维护公共状态页。
- 初始化结构精简为 `AGENTS.md`、`docs/wiki/index.md`、`docs/wiki/project.md` 和 `docs/wiki/thread-memory/`。

## 1.0.0 - 2026-05-12

- 首次公开发布。
- 提供 Codex 项目记忆初始化能力。
- 支持生成项目级 `AGENTS.md` 和 `docs/wiki` 记忆结构。
