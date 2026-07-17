# AIInterviewer 开发文档

## 文档索引

| 文档 | 用途 | 读者 |
|---|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 项目架构总览、技术栈、路由设计 | 开发者 / AI Agent |
| [CODING_STANDARDS.md](CODING_STANDARDS.md) | ArkTS 编码规范、Code Review Checklist | 所有贡献者 |
| [MODULE_INTERFACES.md](MODULE_INTERFACES.md) | 各模块导出接口签名、参数类型、调用示例 | 开发者 / AI Agent |
| [DATA_FLOW.md](DATA_FLOW.md) | 完整面试流程数据流、状态管理策略、异步操作模式 | 开发者 |
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | 分支策略、提交规范、AI Agent 操作规则 | 所有贡献者 |
| [COMPETITION_ARCHITECTURE.md](COMPETITION_ARCHITECTURE.md) | 比赛提交用技术架构说明书 | 评委 / 答辩 |

## 阅读顺序建议

- **新加入开发者**：ARCHITECTURE → CODING_STANDARDS → GIT_WORKFLOW
- **开始写代码前**：MODULE_INTERFACES → DATA_FLOW
- **准备比赛材料**：COMPETITION_ARCHITECTURE

## 文档约定

- 所有文档中的代码示例应反映**目标状态**（修复后），而非当前代码中的占位符
- 接口签名与 `.ets` 源文件不一致时，以源文件为准并提 issue 同步文档
- 文档修改走 `docs/` 分支，与代码变更分开提交
