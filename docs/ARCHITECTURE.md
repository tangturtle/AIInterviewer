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

## 模块分层（规划）

项目采用经典三层架构，各层职责明确、单向依赖：

```
┌─────────────────────────────────────────────────┐
│                    UI 层 (pages)                  │
│  Index.ets  ──  Interview.ets  ──  Report.ets   │
│  首页/JD输入      面试答题页       反馈报告页     │
├─────────────────────────────────────────────────┤
│                  工具层 (utils)                   │
│  PreferencesManager.ets  │  http.ts  │  prompt.ts│
│  API Key 持久化          │  网络请求  │ 提示词工程 │
├─────────────────────────────────────────────────┤
│                LLM API 服务层（外部）              │
│              LLM 大语言模型推理接口                │
└─────────────────────────────────────────────────┘
```

### 层间通信规则

- **UI 层 → 工具层**：页面通过 `import` 调用 utils 导出函数，传递 `Context` 和业务参数
- **工具层 → LLM API**：`http.ts` 封装 POST 请求，携带 API Key 和 prompt 负载
- **UI 层禁止直接调用网络 API**：所有网络请求经过 `utils/http.ts`
- **UI 层禁止直接读写 Preferences**：通过 `utils/PreferencesManager.ts` 操作

## 当前代码资产

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets          # UIAbility 生命周期，加载 pages/Index
├── entrybackupability/
│   └── EntryBackupAbility.ets    # 备份扩展（BackupExtensionAbility）
├── pages/
│   ├── Index.ets                 # 首页 JD 输入（占位 → 待实现完整 UI）
│   ├── Interview.ets             # 面试答题页（占位）
│   └── Report.ets                # 面试报告页（占位）
└── utils/
    ├── PreferencesManager.ets    # API Key 持久化（save/get/has）
    ├── http.ts                   # HTTP POST 封装（⚠️ 含占位符需修复）
    └── types.ts                  # 共享类型定义（ParsedJD, QAPair, Report 等）
```

### 尚未实现的规划模块

| 模块 | 状态 | 说明 |
|---|---|---|
| `utils/prompt.ts` | ❌ 未创建 | LLM 提示词工程 — JD 解析、面试题生成、追问、评分 |
| `pages/Interview.ets` | ⏳ 占位页 | 面试答题页 — 展示题目、语音/文字输入、计时（路由就绪） |
| `pages/Report.ets` | ⏳ 占位页 | 反馈报告页 — 三维度评分、改进建议（路由就绪） |
| 元服务卡片 | ❌ 未实现 | 规划中的鸿蒙特色功能 |

## 路由设计

路由表注册在 `entry/src/main/resources/base/profile/main_pages.json`，格式：

```json
{
  "src": [
    "pages/Index",
    "pages/Interview",
    "pages/Report"
  ]
}
```

页面导航使用 `@ohos.router`（`router.pushUrl` / `router.back`），传参通过 `router.RouterOptions.params`。

## 页面状态机

```
┌──────────┐   输入/粘贴 JD    ┌────────────┐
│  Index   │ ──────────────→   │ Interview  │
│ (首页)   │                   │ (面试答题)  │
└──────────┘                   └─────┬──────┘
      ↑                              │ 三轮完成
      │                              ↓
      │                       ┌────────────┐
      │                       │  Report    │
      └───────────────────────│ (反馈报告)  │
        再来一次               └────────────┘
```

- **Index**：JD 输入/粘贴 → 点击开始面试 → pushUrl 到 Interview
- **Interview**：展示题目 → 用户回答 → 追问（最多三轮）→ 自动跳转 Report
- **Report**：展示三维度评分 → "再来一次" → back 到 Index

## API 设计原则

1. **无第三方 SDK 依赖** — 所有网络请求使用 `@ohos.net.http` 原生 API
2. **API Key 运行时配置** — 通过 Preferences 存储，不硬编码
3. **流式输出规划** — 后续通过 `@ohos.net.http` 的 `onDataReceive` 实现流式响应
4. **请求封装** — `utils/http.ts` 统一处理 Authorization 头、JSON 序列化、错误处理

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
