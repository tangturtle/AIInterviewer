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
| `parseFollowUpResponse(response: string): string \| null` | 解析 LLM 返回的追问纯文本 | 同步 |

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
| 路由方式 | Navigation 默认页（NavPathStack 为空时由 App.ets 渲染） |
| 接收参数 | 无 |
| @State | `jdText`, `hasKey`, `selectedModel`, `modelOptions`, `modelIndex`, `balanceInfo`, `connectionStatus`, `statusType` |
| 主要交互 | 输入/粘贴 JD → 检查 API Key（无则 replacePath 到 Setting）→ 模型选择（支持缓存恢复+自动拉取）→ 点击开始 → `navStack.pushPath({ name: 'Interview', param: { jdText } })` |

### Interview.ets（面试答题页）

| 特性 | 说明 |
|---|---|
| 路由方式 | `navStack.pushPath({ name: 'Interview', param: { jdText } })` |
| 接收参数 | `jdText: string` |
| @State | `pageState: string`, `parsedJD`, `currentRound: number`, `currentQuestion`, `currentAnswer`, `followUpQuestion`, `followUpAnswer`, `qaHistory`, `errorMessage`, `retryCount` |
| 主要交互 | 解析 JD → 展示题目 → 用户输入回答 → LLM 追问（每轮 1 次追问，共 3 轮）→ 生成 Report → replacePath |
| 出口 | 三轮完成后 `navStack.replacePath({ name: 'Report', param: { reportJson: JSON.stringify(report) } })` |

### Report.ets（反馈报告页）

| 特性 | 说明 |
|---|---|
| 路由方式 | `navStack.replacePath({ name: 'Report', param: { reportJson } })` |
| 接收参数 | `reportJson: string`（JSON 序列化的 InterviewReport） |
| @State | `report: InterviewReport \| null` |
| 主要交互 | 展示总分 + 三维度（技术/表达/逻辑）评分 + 评语 + 建议列表 → "再来一次" → `navStack.pop()` |
| 出口 | 返回 Index |

### Setting.ets（配置页）

| 特性 | 说明 |
|---|---|
| 路由方式 | `navStack.pushPath({ name: 'Setting' })` 或 replacePath |
| 接收参数 | 无 |
| @State | `providerIndex`, `apiKeyInput`, `testResult`, `isTesting`, `balanceInfo`, `modelOptions`, `modelIndex`, `selectedModel`, `savedFeedback`, `isApiFocused` |
| 主要交互 | 选择供应商 → 输入 API Key → 检测连通性 → 获取模型列表 → 选择模型 → 确认保存 → `navStack.pop()` |
| 出口 | 保存成功 800ms 后 pop 回 Index |

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
  ├── utils/PreferencesManager.ets  (hasApiKey, getApiKey, saveModel, getTestCache, ...)
  ├── utils/http.ts                 (fetchModels)
  └── navStack.pushPath → Interview.ets

Interview.ets
  ├── utils/PreferencesManager.ets  (getApiKey, getModel)
  ├── utils/prompt.ts               (callLLM, buildJDPrompt, parseJDResponse, buildQuestionPrompt, ...)
  ├── utils/types.ts                (ParsedJD, QAPair, InterviewReport, ...)
  └── navStack.replacePath → Report.ets

Report.ets
  ├── utils/types.ts                (InterviewReport)
  └── navStack.pop → Index.ets

Setting.ets
  ├── utils/PreferencesManager.ets  (saveApiKey, getApiKey, saveProvider, getProvider, saveTestCache, ...)
  ├── utils/http.ts                 (testConnection, fetchModels, fetchBalance)
  └── navStack.pop → Index.ets
```

各页面**禁止直接 import 系统 API**（`@ohos.net.http`、`@ohos.data.preferences`），所有系统级操作统一经过 `utils/` 层。
