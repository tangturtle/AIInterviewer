# AIInterviewer 模块接口契约

> 本文件定义各模块的导出接口签名、参数约束与返回值类型，作为 AI Agent 与开发者对接的精确参考。

## 1. utils/PreferencesManager.ets

API Key、供应商、模型的持久化管理。基于 `@ohos.data.preferences` 实现。

### 导出的常量

```typescript
export const BUILTIN_ENDPOINTS: Record<string, string> = {
  'openai': 'https://api.openai.com/v1/chat/completions',
  'deepseek': 'https://api.deepseek.com/chat/completions'
};

export const DEFAULT_MODELS: Record<string, string> = {
  'openai': 'gpt-4',
  'deepseek': 'deepseek-v4-flash'
};

export const DEFAULT_PROVIDER = 'deepseek';
```

### 导出函数

| 函数签名 | 说明 | 异步 |
|---|---|---|
| `saveApiKey(context: Context, key: string): Promise<void>` | 持久化保存 API Key | ✅ |
| `getApiKey(context: Context): Promise<string \| null>` | 读取 API Key，未设置返回 null | ✅ |
| `hasApiKey(context: Context): Promise<boolean>` | 检查是否已配置 API Key | ✅ |
| `saveProvider(context: Context, provider: string): Promise<void>` | 保存供应商名（如 `'openai'`, `'deepseek'`） | ✅ |
| `getProvider(context: Context): Promise<string>` | 读取供应商名，未设置返回默认值 | ✅ |
| `getEndpoint(context: Context): Promise<string>` | 获取当前供应商的完整 API 端点 URL | ✅ |
| `saveModel(context: Context, model: string): Promise<void>` | 保存选中的模型名 | ✅ |
| `getModel(context: Context): Promise<string>` | 读取模型名，未设置返回供应商默认模型 | ✅ |

**使用约束：**
- `context` 参数需从 UIAbility 或页面传入（`getContext()`），不得模块级缓存
- API Key 仅存储在本地 Preferences，**永不提交 git**
- 调用 `saveApiKey` 后自动 `flush()`，无需额外持久化操作

### 调用示例

```typescript
import { saveApiKey, hasApiKey, saveProvider, getModel, BUILTIN_ENDPOINTS } from '../utils/PreferencesManager';

// 保存 API Key
await saveApiKey(getContext(), 'sk-xxx');

// 检查是否已配置
if (await hasApiKey(getContext())) { /* 已配置 */ }

// 选择和保存供应商
await saveProvider(getContext(), 'deepseek');
const model = await getModel(getContext())); // → 'deepseek-v4-flash'
```

---

## 2. utils/http.ts

HTTP 网络请求封装。基于 `@ohos.net.http`。

### 导出函数

| 函数签名 | 说明 | 异步 |
|---|---|---|
| `post(url: string, body: object, apiKey: string): Promise<string>` | 发送 POST 请求，connectTimeout=15s, readTimeout=30s，非 2xx 抛出 Error | ✅ |
| `testConnection(apiKey: string, endpoint: string, model?: string): Promise<boolean>` | 连通性测试（POST 最小请求），connectTimeout=10s, readTimeout=15s | ✅ |
| `fetchModels(apiKey: string, endpoint: string): Promise<string[]>` | 获取可用模型列表，失败返回空数组 | ✅ |
| `fetchBalance(apiKey: string): Promise<string>` | 查询 DeepSeek 账户余额，失败返回空字符串 | ✅ |

### 请求格式

```
POST {url}
Content-Type: application/json
Authorization: Bearer {apiKey}

{JSON.stringify(body)}
```

### 返回值

```typescript
// post 成功：LLM API 返回的原始 JSON 字符串
Promise<string>

// post 失败：抛出 Error（网络错误 / 非 2xx 状态码）
// testConnection 失败返回 false（不抛异常）
// fetchModels 失败返回 []（不抛异常）
// fetchBalance 失败返回 ''（不抛异常）
```

### 调用示例

```typescript
import { post, fetchModels, testConnection } from '../utils/http';

// LLM 调用
const result = await post(
  'https://api.deepseek.com/chat/completions',
  {
    model: 'deepseek-v4-flash',
    messages: [{ role: 'user', content: 'Hello' }]
  },
  apiKey
);

// 连通性测试
const ok = await testConnection(apiKey, endpoint, 'deepseek-v4-flash');

// 模型列表
const models = await fetchModels(apiKey, endpoint);
```

---

## 3. utils/prompt.ts

提示词工程模块，管理所有 LLM prompt 模板和解析逻辑。

### 导出常量

```typescript
export const DEFAULT_ENDPOINT = 'https://api.deepseek.com/chat/completions';
export const DEFAULT_MODEL = 'deepseek-v4-flash';
```

### 导出函数

| 函数签名 | 说明 | 异步 |
|---|---|---|
| `callLLM(apiKey: string, systemPrompt: string, userPrompt: string, endpoint?: string, model?: string): Promise<string>` | LLM 调用封装（POST + 响应校验） | ✅ |
| `buildJDPrompt(jdText: string): string` | 根据 JD 文本生成结构化解析 prompt | 同步 |
| `parseJDResponse(response: string): ParsedJD \| null` | 解析 LLM 返回的 JD 结构化数据 | 同步 |
| `buildQuestionPrompt(jd: ParsedJD, round: number): string` | 根据 JD 和轮次生成面试题 prompt | 同步 |
| `parseQuestionResponse(response: string): InterviewQuestion \| null` | 解析 LLM 返回的题目 | 同步 |
| `buildFollowUpPrompt(question: InterviewQuestion, answer: string, history: QAPair[]): string` | 根据用户回答生成追问 prompt | 同步 |
| `buildReportPrompt(qaHistory: QAPair[], jd: ParsedJD): string` | 生成三维度评分 prompt | 同步 |
| `parseReportResponse(response: string): InterviewReport \| null` | 解析 LLM 返回的评分报告 | 同步 |

### 数据类型

```typescript
interface ParsedJD {
  position: string;           // 职位名称
  requirements: string[];     // 关键要求
  responsibilities: string[]; // 职责描述
  skills: string[];           // 技能关键词
}

interface InterviewQuestion {
  text: string;               // 题目正文
  type: 'technical' | 'behavioral' | 'project'; // 题目类型
  focusArea: string;          // 考察维度
}

interface QAPair {
  question: InterviewQuestion;
  answer: string;
  followUps: FollowUpItem[];
}

interface FollowUpItem {
  question: string;           // 追问文本
  answer: string;             // 用户对追问的回答
}

interface InterviewReport {
  overall: number;            // 总分（百分制）
  dimensions: {
    technical: { score: number; comment: string; suggestions: string[] };
    expression: { score: number; comment: string; suggestions: string[] };
    logic: { score: number; comment: string; suggestions: string[] };
  };
  summary: string;            // 综合评价
}
```

---

## 4. 页面组件接口

### Index.ets（首页）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Index` |
| 接收参数 | 无（入口页） |
| @State | `jdText: string`（JD 输入文本）, `apiKeyDialog: boolean`（API Key 弹窗控制） |
| 主要交互 | 输入/粘贴 JD → 校验 API Key（无则弹窗） → 点击开始 → `router.pushUrl({ url: 'pages/Interview', params: { jdText, apiKey } })` |
| 前置条件 | 首次使用时需配置 API Key（通过弹窗调用 `saveApiKey`） |

### Interview.ets（面试答题页）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Interview` |
| 接收参数 | `jdText: string`, `apiKey: string` |
| @State | `currentQuestion: InterviewQuestion`, `round: number`, `answer: string`, `qaHistory: QAPair[]`, `pageState: PageState`（7 态状态机） |
| 主要交互 | 解析 JD → 展示题目 → 用户输入回答 → LLM 追问（最多三轮）→ 生成 Report → replaceUrl |
| 出口 | 三轮完成后 `router.replaceUrl({ url: 'pages/Report', params: { report, qaHistory, jd } })` |

### Report.ets（反馈报告页）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Report` |
| 接收参数 | `reportJson: string`（JSON 序列化的 InterviewReport） |
| @State | `report: InterviewReport`（从 reportJson 解析） |
| 主要交互 | 展示总分 + 三维度评分（分数/评语/建议列表） → "再来一次" 按钮 → `router.back()` |
| 出口 | 返回首页 |

### Setting.ets（配置页）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Setting` |
| 接收参数 | 无 |
| @State | `apiKeyInput: string`, `providerIndex: number`, `models: string[]`, `selectedModel: string`, `testResult: string`, `balance: string` |
| 主要交互 | 选择供应商 → 输入 API Key → 检测连通性 → 获取模型列表 → 选择模型 → 确认保存 → replaceUrl 回 Index |
| 出口 | `router.replaceUrl({ url: 'pages/Index' })` |

---

## 5. LLM API 契约（外部接口）

### 支持的供应商

| 供应商 | 端点 | 默认模型 |
|---|---|---|
| DeepSeek | `POST https://api.deepseek.com/chat/completions` | `deepseek-v4-flash` |
| OpenAI | `POST https://api.openai.com/v1/chat/completions` | `gpt-4` |

> **DeepSeek 注意**：`/v1/chat/completions` 也兼容（是 OpenAI SDK 自动追加的路径别名），但推荐使用无 `/v1/` 的规范 URL。`deepseek-chat` 将于 2026-07-24 废弃，当前默认使用 `deepseek-v4-flash`。

### 请求格式

```http
POST {endpoint}
Authorization: Bearer {apiKey}
Content-Type: application/json

{
  "model": "deepseek-v4-flash",
  "messages": [
    { "role": "system", "content": "{system_prompt}" },
    { "role": "user", "content": "{user_prompt}" }
  ],
  "temperature": 0.7
}
```

### 响应格式（预期）

```json
{
  "id": "chatcmpl-xxx",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "{模型返回文本}"
      }
    }
  ],
  "usage": {
    "prompt_tokens": 100,
    "completion_tokens": 200,
    "total_tokens": 300
  }
}
```

### LLM 端点配置

| 配置项 | 说明 |
|---|---|
| 默认端点 | 通过 Preferences 配置（`getEndpoint`），内置 DeepSeek/OpenAI 预置 |
| 默认模型 | 通过 Preferences 配置（`getModel`），按供应商有不同默认值 |
| 支持接入 | 兼容 OpenAI Chat Completions API 格式的任何 LLM 服务 |

---

## 6. 模块依赖图

```
Index.ets
  ├── utils/PreferencesManager.ets  (hasApiKey, saveApiKey)
  └── router.pushUrl → Interview.ets

Interview.ets
  ├── utils/http.ts                 (LLM 请求 via callLLM)
  ├── utils/prompt.ts               (buildJDPrompt, parseJDResponse, buildQuestionPrompt, ...)
  ├── utils/types.ts                (ParsedJD, QAPair, InterviewReport, ...)
  └── router.replaceUrl → Report.ets

Report.ets
  ├── utils/types.ts                (InterviewReport)
  └── router.back → Index.ets

Setting.ets
  ├── utils/PreferencesManager.ets  (saveApiKey, getApiKey, saveProvider, ...)
  ├── utils/http.ts                 (testConnection, fetchModels, fetchBalance)
  └── router.replaceUrl → Index.ets
```

各页面**禁止直接 import 系统 API**（`@ohos.net.http`、`@ohos.data.preferences`），所有系统级操作统一经过 `utils/` 层。
