# AIInterviewer 项目架构总览

> AI 模拟面试官 · HarmonyOS 应用 · SDK 6.1.1 · Stage 模型

## 技术栈

| 维度 | 选用技术 |
|---|---|
| 语言 | ArkTS（TypeScript 超集）+ ArkUI 声明式 UI |
| 框架 | HarmonyOS SDK 6.1.1，Stage 模型 |
| 构建 | Hvigor（`hvigorw assembleHap`） |
| IDE | DevEco Studio |
| 包管理 | ohpm（`oh-package-lock.json5`） |
| 测试 | `@ohos/hypium`（describe/it/expect） |
| 网络 | `@ohos.net.http` |
| 持久化 | `@ohos.data.preferences`（ArkData） |
| 日志 | `@kit.PerformanceAnalysisKit` / `hilog`，DOMAIN = `0x0000` |

## 模块分层

项目采用经典三层架构，各层职责明确、单向依赖：

```
┌─────────────────────────────────────────────────────────┐
│                    UI 层 (pages)                         │
│  Index.ets → Interview.ets → Report.ets                 │
│  首页/JD输入   面试答题+追问   三维度评分报告              │
│  + Setting.ets（API供应商/模型/Key配置+连通测试）         │
├─────────────────────────────────────────────────────────┤
│                  工具层 (utils)                          │
│  PreferencesManager.ets │ http.ts │ prompt.ts │ types.ts│
│  Key/供应商/模型持久化    │ 网络+连通│ 提示词工程 │ 类型定义 │
├─────────────────────────────────────────────────────────┤
│                LLM API 服务层（外部）                      │
│              LLM 大语言模型推理接口                        │
└─────────────────────────────────────────────────────────┘
```

### 层间通信规则

- **UI 层 → 工具层**：页面通过 `import` 调用 utils 导出函数，传递 `Context` 和业务参数
- **工具层 → LLM API**：`http.ts` 封装 POST/GET 请求，携带 API Key 和 prompt 负载
- **UI 层禁止直接调用网络 API**：所有网络请求经过 `utils/http.ts`
- **UI 层禁止直接读写 Preferences**：通过 `utils/PreferencesManager.ts` 操作

## 当前代码资产

```
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── pages/
│   ├── Index.ets          # 首页：JD输入/粘贴、API Key配置弹窗、路由跳转
│   ├── Interview.ets      # 面试页：JD解析→3轮出题+追问→LLM评分→跳转Report
│   ├── Report.ets         # 报告页：总分+三维度（技术/表达/逻辑）评分+建议
│   └── Setting.ets        # 配置页：供应商选择、API Key输入、连通测试、模型列表、余额查询
└── utils/
    ├── types.ts           # ParsedJD, InterviewQuestion, QAPair, InterviewReport, FollowUpItem
    ├── PreferencesManager.ets  # saveApiKey/getApiKey/hasApiKey, saveProvider/getProvider/getEndpoint,
    │                         # saveModel/getModel, BUILTIN_ENDPOINTS/DEFAULT_MODELS/DEFAULT_PROVIDER 常量
    ├── http.ts            # post, testConnection, fetchModels, fetchBalance
    └── prompt.ts          # callLLM, buildJDPrompt/parseJDResponse, buildQuestionPrompt/parseQuestionResponse,
                          # buildFollowUpPrompt, buildReportPrompt/parseReportResponse
```

### 已实现 vs 规划中

| 模块 | 状态 |
|---|---|
| 4 个页面 (Index/Interview/Report/Setting) | ✅ 已实现 |
| utils 层全部 4 个模块 | ✅ 已实现 |
| DeepSeek/OpenAI 双供应商 | ✅ 已实现 |
| 连通性测试 + 模型列表拉取 + 余额查询 | ✅ 已实现 |
| 流式输出（LLM 边收边渲染） | 🔄 Phase 3 |
| 分布式数据对象（手机→平板同步） | 🔄 Phase 3 |
| 元服务卡片 | 🔄 Phase 4 |

## 路由设计

路由表注册在 `entry/src/main/resources/base/profile/main_pages.json`，格式：

```json
{
  "src": [
    "pages/Index",
    "pages/Interview",
    "pages/Report",
    "pages/Setting"
  ]
}
```

页面导航使用 `@ohos.router`（`router.pushUrl` / `router.replaceUrl` / `router.back`），传参通过 `router.RouterOptions.params`。

> **注意**：`@ohos.router` 在 API 24 已标记为 deprecated，后续应迁移到 `@ohos.arkui.advanced.Navigation`。

## 页面状态机

```
Index → Interview → Report
  ↑                    │
  └────────────────────┘

Index ← Setting（配置完成后 replaceUrl 回 Index）
```

- **Index**：JD 输入/粘贴 → 点击开始面试 → pushUrl 到 Interview
- **Interview**：展示题目 → 用户回答 → 追问（最多三轮）→ 自动生成 Report 并 replaceUrl 到 Report
- **Report**：展示三维度评分 + 改进建议 → "再来一次" → back 到 Index
- **Setting**：选择供应商、输入 API Key、连通测试、拉取模型列表、选择模型 → replaceUrl 回 Index

## API 设计原则

1. **无第三方 SDK 依赖** — 所有网络请求使用 `@ohos.net.http` 原生 API
2. **API Key 运行时配置** — 通过 Preferences 存储，不硬编码
3. **超时配置** — connectTimeout=15s, readTimeout=30s，避免默认 60s 超时导致"卡死"
4. **请求封装** — `utils/http.ts` 统一处理 Authorization 头、JSON 序列化、错误处理、非 2xx 异常

## 关键文件路径

| 用途 | 路径 |
|---|---|
| 应用入口 | `entry/src/main/ets/entryability/EntryAbility.ets` |
| 首页 | `entry/src/main/ets/pages/Index.ets` |
| 工具层 | `entry/src/main/ets/utils/` |
| 资源文件 | `entry/src/main/resources/base/element/` |
| 路由配置 | `entry/src/main/resources/base/profile/main_pages.json` |
| 构建配置 | `build-profile.json5` |
| 文档目录 | `docs/` |
