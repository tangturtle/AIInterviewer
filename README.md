# AIInterviewer

> 鸿蒙高校创新赛 · 应用创新赛道

你粘贴一份岗位 JD。应用解析出技能栈，按技术、行为、项目经验三类出题。你答题，每个回答触发最多三轮追问。结束后拿到内容质量、表达逻辑、改进方向三个维度的评分和建议。

## 功能

**JD 解析。** LLM 从 JD 文本中提取职位名称、关键要求、职责描述、技能关键词。

**面试出题。** 基于解析结果生成混合题型 — 技术深度、行为面试、项目经验。

**智能追问。** 追问方向和深度取决于你的回答内容，每道题最多三轮。

**评分报告。** 从内容质量、表达逻辑、改进方向三个维度打分，附具体建议。

**跨端协同（规划中）。** 手机答题，平板看报告。通过鸿蒙分布式数据对象同步面试进度。

## 架构

```
UI 层 (pages)
  Index.ets → Interview.ets → Report.ets
        │
工具层 (utils)
  PreferencesManager.ets   API Key 读写
  http.ts                  网络请求
  prompt.ts                提示词（未创建）
        │
LLM API（外部）
  兼容 OpenAI 格式的模型服务
```

单向依赖。UI 不直接调系统 Kit — 网络和存储都走 utils。

完整架构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 当前状态

| 做了什么 | 状态 |
|---|---|
| EntryAbility、页面路由 | ✅ |
| Index.ets（Hello World 占位） | ✅ |
| PreferencesManager.ets — API Key 存取 | ✅ |
| http.ts — HTTP POST 封装 | ⚠️ 类型标注含占位符，需修 |
| prompt.ts — 提示词工程 | ❌ |
| Interview.ets、Report.ets | ❌ |
| 流式输出、分布式数据对象、元服务卡片 | ❌ |

## 技术栈

HarmonyOS SDK 6.1.1，Stage 模型。ArkTS + ArkUI 声明式 UI。Hvigor 构建。

| 做什么 | 用什么 |
|---|---|
| 网络 | `@ohos.net.http` |
| 存储 | `@ohos.data.preferences` |
| 日志 | `@kit.PerformanceAnalysisKit` / hilog |
| 测试 | `@ohos/hypium` |
| AI | LLM API（兼容 OpenAI 格式） |

不引入第三方 npm/ohpm 运行时包。

## 跑起来

你要有：

- DevEco Studio 5.0+
- HarmonyOS SDK 6.1.1+
- 一个 LLM API Key（DeepSeek、通义千问等兼容 OpenAI 格式的服务）

```bash
git clone https://github.com/tangturtle/AIInterviewer.git
# 用 DevEco Studio 打开项目根目录，等依赖同步，点运行
```

API Key 配置页面还没做。当前你需要在代码里手动调 `saveApiKey(context, 'your-key')`。数据只存本地 Preferences，不进 git。

## 目录

```
AIInterviewer/
├── docs/                       # 开发文档
│   ├── ARCHITECTURE.md
│   ├── CODING_STANDARDS.md
│   ├── COMPETITION_ARCHITECTURE.md
│   ├── DATA_FLOW.md
│   ├── GIT_WORKFLOW.md
│   └── MODULE_INTERFACES.md
├── entry/src/main/ets/
│   ├── entryability/           # EntryAbility ✅
│   ├── pages/
│   │   ├── Index.ets           # 首页 ✅
│   │   ├── Interview.ets       # ❌
│   │   └── Report.ets          # ❌
│   └── utils/
│       ├── PreferencesManager.ets  # ✅
│       ├── http.ts             # ⚠️
│       └── prompt.ts           # ❌
├── AppScope/
└── build-profile.json5
```

## 文档

| 文件 | 内容 |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构、路由、页面状态机 |
| [CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | 编码规范、Review Checklist |
| [MODULE_INTERFACES.md](docs/MODULE_INTERFACES.md) | 接口签名、参数类型、调用示例 |
| [DATA_FLOW.md](docs/DATA_FLOW.md) | 数据流、状态管理、异步模式 |
| [GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) | 分支策略、提交规范 |
| [COMPETITION_ARCHITECTURE.md](docs/COMPETITION_ARCHITECTURE.md) | 比赛技术架构说明书 |

## 贡献

写代码前先读两份文件：

- [CODING_STANDARDS.md](docs/CODING_STANDARDS.md) — 禁用 `any`，字符串走 `$r()`，hilog tag 统一用 `'AIInterviewer'`
- [GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) — 提交前向用户汇报变更，等批准后再 commit

API Key 不进代码、不进 git。`utils/` 下禁止写实际密钥值。

## 许可证

学习交流用途。
