# 更新记录

## 1.4.4 - 2026-05-24

- 补齐 shell `doctor` 的 `POSSIBLE_CONTINUATION_FORK` 检查，和 PowerShell 版保持一致。
- 对齐 shell 与 PowerShell 的扫描范围：`threads/` 和 workstream `events/` 只读取直接子文件，不再递归索引嵌套目录。
- 调整测试脚本的 bash 检测，缺少 bash 时跳过 shell 专项测试，而不是在前置 parity 测试中直接失败。
- 增加回归测试，覆盖 shell 分叉检测、嵌套 thread/event 目录的跨平台一致性。

## 1.4.3 - 2026-05-24

- 修复 PowerShell `memory_tools.ps1` 解析多行 frontmatter 时误把缩进内容里的 `Note: value` 当成新字段的问题。
- 统一 `latest_event` 选择规则：PowerShell 和 shell 都按事件文件名协议排序，而不是一个按修改时间、一个按文件名。
- 优化 shell `thread-index` 生成流程，生成索引和统计状态计数合并为一次线程列表遍历。
- 移除 shell `doctor` 函数内的 EXIT trap 残留，避免后续函数或未来维护逻辑被隐式 trap 影响。
- 增加回归测试，覆盖缩进冒号行的 block scalar、跨平台 latest event 选择规则。

## 1.4.2 - 2026-05-24

- 修复 shell 版 `memory_tools.sh` 手动生成 JSON 时对换行、引号、反斜杠和 Windows UTF-8 BOM 的处理问题。
- 对齐 shell 和 PowerShell 生成的索引结构，补齐线程计数、文件大小、修改时间、workstream snapshot、active threads 和 latest event 字段，并减少重复扫描。
- 修复 shell `doctor` 遇到错误仍返回成功退出码的问题。
- 修复 shell orphan workstream 检测误读正文内容的问题，只按 thread frontmatter 的 `workstream` 字段判断。
- 更新 README 中维护脚本的真实调用方式，并将示例线程文件名统一为秒级精度。
- 增加回归测试，覆盖跨平台索引结构、block scalar frontmatter、JSON 转义、BOM 兼容、doctor 退出码和 shell 初始化后损坏检测。

## 1.4.1 - 2026-05-24

- 修复初始化脚本生成的 `AGENTS.md` 启动顺序：先读取 `.codex-memory/system/` 索引，再按需打开 thread 和 workstream 原文。
- 新增 POSIX shell 版维护工具 `memory_tools.sh`，macOS/Linux 不需要安装 PowerShell 也能运行 `doctor` 和 `index`。
- 增强 `doctor`：检查 thread 指向不存在的 workstream、active workstream 没有任何 thread 引用、GitHub/AWS/JWT 等常见 token 形态。
- 清理 PowerShell `index` 输出的尾部换行，避免不同 PowerShell 版本下出现多余空行。
- README 和 skill 文档补充确定性工具的边界：它负责检查和索引，不是强制运行时。

## 1.4.0 - 2026-05-24

- 新增轻量确定性维护脚本 `memory_tools.ps1`。
- `doctor` 支持只读检查记忆结构、Git 隐私默认值、旧版 `docs/wiki/`、断开的 `continues_from`、可能的分叉、过期 snapshot 和疑似密钥。
- `index` 支持生成 `.codex-memory/system/thread-index.json` 和 `.codex-memory/system/workstream-index.json`，让 Codex 启动时先看索引再按需读取原始记忆。
- 初始化结构新增 `.codex-memory/system/`，用于保存可重建的工具生成文件。
- README 和 skill 文档补充确定性维护工具的使用边界。

## 1.3.5 - 2026-05-24

- 移除初始化脚本创建 `.gitkeep` 的行为；`.codex-memory/` 默认本地忽略时不再生成无意义的占位文件。
- 修复旧版迁移：`project-overview.md` 不再同时写入 `project.md` 和 legacy thread memory。
- 修复 `--force` 对旧版迁移 `project.md` 不生效的问题。
- Shell 初始化模板改用 quoted heredoc 生成 `AGENTS.md` 主体，降低未来模板内容被 shell 展开的风险。
- 线程文件名建议从分钟级改为秒级，降低并发创建冲突。
- 补充轻量测试脚本，覆盖初始化、旧版迁移、`--force` 和 shell 路径。

## 1.3.4 - 2026-05-24

- 明确新 Codex 会话默认创建新的 thread memory，旧 thread memory 默认只读，不再把“续写旧任务”误写成“继续写旧线程文件”。
- 新增 `continues_from` 继承关系：新线程续写旧任务时读取旧 thread，并在新 thread 中记录来源。
- 明确 workstream 只负责归组同一任务，不能替代读取旧 thread 上下文。
- 精简 README，让安装、自动记忆规则和常见场景更直观。

## 1.3.3 - 2026-05-24

- 将启动规则从“列出记忆让用户选择”改为“自动判断当前任务应该使用的线程记忆和 workstream”。
- README 改为自然使用方式：用户正常说任务即可，不需要记住或手动指定 workstream。
- 初始化脚本生成的 `AGENTS.md` 同步新规则：高置信自动接续，低置信、冲突、隐私共享或破坏性操作时才询问用户。

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
