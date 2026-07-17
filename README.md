# AIInterviewer — AI 模拟面试官

> 鸿蒙高校创新赛 · 应用创新赛道  
> HarmonyOS SDK 6.1.1 · Stage 模型 · ArkTS + ArkUI

---

粘贴一份岗位 JD，AI 自动解析技能栈，按技术深度、行为面试、项目经验三类出具题目。你逐题作答，每道回答触发最多三轮智能追问。结束时从**内容质量、表达能力、逻辑结构**三个维度生成评分报告和改进建议。

---

## 功能

**📄 JD 智能解析** — LLM 从 JD 文本中提取职位名称、关键要求、职责描述和技能关键词，结构化展示。

**🎯 混合出题** — 基于解析结果生成三类题目：技术深度、行为面试、项目经验，适配不同岗位特点。

**💬 智能追问** — 追问方向与深度取决于你的回答内容，每道题最多三轮，模拟真实面试的层层深入。

**📊 三维度评分** — 从内容质量、表达能力、逻辑结构三个维度打分（百分制），附具体改进建议。

**⚙️ 运行时配置** — 应用内配置页面管理 API Key、供应商选择（DeepSeek / OpenAI）、模型选择；配置仅存本地 Preferences，不提交 git。

**📱 跨端协同（规划中）** — 手机答题 + 平板看报告，通过鸿蒙分布式数据对象同步面试进度。

---

## 快速开始

### 前提

- DevEco Studio 5.0+
- HarmonyOS SDK 6.1.1+
- 一个 LLM API Key（DeepSeek、通义千问等兼容 OpenAI 格式的服务）

### 运行

```bash
git clone https://github.com/tangturtle/AIInterviewer.git
```

用 DevEco Studio 打开 `AIInterviewer/` 目录，等待 ohpm 依赖同步，点击 **Run**（模拟器或真机）。

首次启动会自动进入**配置页面**（API Setting），依次：
1. 选择接口供应商（默认 DeepSeek）
2. 输入 API Key
3. 点击「检测连通性」验证网络和密钥
4. 从自动获取的模型列表中选取一个
5. 点击「确认」保存

配置后进入首页粘贴 JD 即可开始面试。

---

## 架构

```
├── entry/src/main/ets/
│   ├── entryability/
│   │   └── EntryAbility.ets          # UIAbility 生命周期
│   ├── pages/
│   │   ├── Index.ets                 # 首页：JD 输入 / 粘贴
│   │   ├── Interview.ets             # 面试答题页（7 态状态机）
│   │   ├── Report.ets                # 评分报告页
│   │   └── Setting.ets               # API 配置页
│   └── utils/
│       ├── PreferencesManager.ets    # API Key / 供应商 / 模型持久化
│       ├── http.ts                   # HTTP 封装（POST + 连通性 / 模型 / 余额）
│       ├── prompt.ts                 # 提示词工程（JD 解析 / 出题 / 追问 / 评分）
│       └── types.ts                  # 共享类型定义
├── docs/                             # 开发文档集（见下方索引）
└── AppScope/                         # 应用级配置
```

### 分层

| 层 | 目录 | 职责 |
|---|---|---|
| **UI 层** | `pages/` | 页面组件、状态管理、用户交互 |
| **工具层** | `utils/` | 网络请求、持久化、提示词工程 |
| **外部服务** | — | LLM API（兼容 OpenAI 格式） |

单向依赖：UI → utils → LLM API。页面**不直接调用**系统 Kit API。

### 技术栈

| 做什么 | 用什么 |
|---|---|
| 语言 / UI | ArkTS + ArkUI 声明式 |
| 网络 | `@ohos.net.http` |
| 存储 | `@ohos.data.preferences` |
| 日志 | `@kit.PerformanceAnalysisKit` / hilog |
| 测试 | `@ohos/hypium` |
| AI | LLM API（兼容 OpenAI 格式） |
| 构建 | Hvigor（无第三方 npm/ohpm 运行时包） |

---

## 当前状态

| 模块 | 状态 | 说明 |
|---|---|---|
| EntryAbility | ✅ | hilog tag `'AIInterviewer'`，路由加载 |
| pages/Index.ets | ✅ | JD 输入、粘贴、API Key 检查、跳转面试 |
| pages/Interview.ets | ✅ | 7 态状态机：JD 解析 → 出题 → 答题 → 追问 → 评分 |
| pages/Report.ets | ✅ | 三维度评分展示 + 再来一次 |
| pages/Setting.ets | ✅ | 供应商选择、API Key 管理、连通性测试、模型下拉、余额查询 |
| utils/PreferencesManager.ets | ✅ | save/get/has API Key + 供应商 + 模型 |
| utils/http.ts | ✅ | POST 封装 + testConnection GET/POST + fetchModels + fetchBalance |
| utils/prompt.ts | ✅ | JD 解析 / 出题 / 追问 / 评分 prompt + 响应解析 |
| utils/types.ts | ✅ | ParsedJD / InterviewQuestion / QAPair / InterviewReport / FollowUpItem |
| 元服务卡片 | ❌ | 规划中 |
| 分布式数据对象 | ❌ | 规划中（手机→平板同步） |
| 流式输出 | ❌ | 规划中 |

---

## 目录结构

```
AIInterviewer/
├── AppScope/                       # 应用名、图标等
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/       # EntryAbility.ets
│       │   ├── entrybackupability/ # EntryBackupAbility.ets
│       │   ├── pages/              # Index / Interview / Report / Setting
│       │   └── utils/              # PreferencesManager / http / prompt / types
│       ├── resources/
│       │   └── base/
│       │       ├── element/        # 字符串资源（string.json）
│       │       ├── media/          # 图标
│       │       ├── profile/        # main_pages.json 路由注册
│       │       └── ...
│       └── module.json5            # 模块配置 + 权限
├── docs/                           # 开发文档
├── build-profile.json5             # 构建配置
└── hvigorfile.ts                   # Hvigor 构建入口
```

---

## 文档索引

| 文档 | 用途 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构总览、路由设计、页面状态机 |
| [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md) | ArkTS 编码规范、Code Review Checklist |
| [docs/MODULE_INTERFACES.md](docs/MODULE_INTERFACES.md) | 模块接口签名、参数类型、调用示例 |
| [docs/DATA_FLOW.md](docs/DATA_FLOW.md) | 面试流程数据流、状态管理、异步模式 |
| [docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) | 分支策略、提交规范 |
| [docs/COMPETITION_ARCHITECTURE.md](docs/COMPETITION_ARCHITECTURE.md) | 比赛提交用技术架构说明书 |

### 阅读顺序建议

- **新加入开发者**：ARCHITECTURE → CODING_STANDARDS → GIT_WORKFLOW
- **开始写代码前**：MODULE_INTERFACES → DATA_FLOW
- **准备比赛材料**：COMPETITION_ARCHITECTURE

---

## 贡献

写代码前先读：

- [CODING_STANDARDS.md](docs/CODING_STANDARDS.md) — 禁用 `any`，字符串走 `$r()`，hilog tag 统一 `'AIInterviewer'`
- [GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md) — 提交前向用户汇报变更，等批准后再 commit

**API Key 不进代码、不进 git。** `utils/` 下禁止写入实际密钥值。

---

## 许可证

学习交流用途。
