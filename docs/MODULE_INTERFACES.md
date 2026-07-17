# AIInterviewer 模块接口契约

> 本文件定义各模块的导出接口签名、参数约束与返回值类型，作为 AI Agent 与开发者对接的精确参考。

## 1. utils/PreferencesManager.ets

API Key 持久化管理。基于 `@ohos.data.preferences` 实现。

### 导出的常量

```typescript
// 内部使用，模块外部无需引用
const STORE_NAME = 'ai_interviewer_prefs';
const KEY_API_KEY = 'ai_interviewer_api_key';
```

### 导出函数

| 函数签名 | 说明 | 异步 |
|---|---|---|
| `saveApiKey(context: Context, key: string): Promise<void>` | 持久化保存 API Key | ✅ |
| `getApiKey(context: Context): Promise<string \| null>` | 读取 API Key，未设置返回 null | ✅ |
| `hasApiKey(context: Context): Promise<boolean>` | 检查是否已配置 API Key | ✅ |

**使用约束：**
- `context` 参数需从 UIAbility 或页面传入（`getContext()`），不得模块级缓存
- API Key 仅存储在本地 Preferences，**永不提交 git**
- 调用 `saveApiKey` 后自动 `flush()`，无需额外持久化操作

### 调用示例

```typescript
import { saveApiKey, getApiKey, hasApiKey } from '../utils/PreferencesManager';

// 保存
await saveApiKey(getContext(), 'sk-xxx');

// 读取
const key = await getApiKey(getContext());

// 检查
if (await hasApiKey(getContext())) { /* 已配置 */ }
```

---

## 2. utils/http.ts

HTTP 网络请求封装。基于 `@ohos.net.http`。

### 导出函数

| 函数签名 | 说明 | 异步 |
|---|---|---|
| `post(url: string, body: object, apiKey: string): Promise<string>` | 发送 POST 请求，返回 JSON 字符串 | ✅ |

### 请求格式

```
POST {url}
Content-Type: application/json
Authorization: Bearer {apiKey}

{JSON.stringify(body)}
```

### 返回值

```typescript
// 成功：LLM API 返回的原始 JSON 字符串
Promise<string>

// 失败：抛出 Error（网络错误 / 非 2xx 状态码）
```

### 调用示例

```typescript
import { post } from '../utils/http';

const result = await post(
  'https://api.openai.com/v1/chat/completions',
  {
    model: 'gpt-4',
    messages: [{ role: 'user', content: 'Hello' }]
  },
  apiKey
);
const data = JSON.parse(result);
```

> ?? 注意：`http.ts` 第3行 `apiKey` 参数类型标注和第9行 Authorization 前缀当前为占位符，需同步修复为以上签名。

---

## 3. utils/prompt.ts（规划中，待创建）

提示词工程模块，管理所有 LLM prompt 模板和解析逻辑。

### 规划的导出函数

| 函数签名 | 说明 | 阶段 |
|---|---|---|
| `buildJDPrompt(jdText: string): string` | 根据 JD 文本生成结构化解析 prompt | 规划 |
| `parseJDResponse(response: string): ParsedJD` | 解析 LLM 返回的 JD 结构化数据 | 规划 |
| `buildQuestionPrompt(jd: ParsedJD, round: number): string` | 根据 JD 和轮次生成面试题 prompt | 规划 |
| `parseQuestionResponse(response: string): InterviewQuestion` | 解析 LLM 返回的题目 | 规划 |
| `buildFollowUpPrompt(question: InterviewQuestion, answer: string, history: QAPair[]): string` | 根据用户回答生成追问 prompt | 规划 |
| `buildReportPrompt(qaHistory: QAPair[], jd: ParsedJD): string` | 生成三维度评分 prompt | 规划 |
| `parseReportResponse(response: string): InterviewReport` | 解析 LLM 返回的评分报告 | 规划 |

### 规划的数据类型

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
  followUps: { question: string; answer: string }[];
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
| @State | `jdText: string`（JD 输入文本） |
| 主要交互 | 输入/粘贴 JD → 点击开始 → `router.pushUrl({ url: 'pages/Interview', params: { jd, apiKey } })` |
| 前置条件 | 首次使用时需配置 API Key（通过弹窗调用 `saveApiKey`） |

### Interview.ets（面试答题页 — 待创建）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Interview` |
| 接收参数 | `jd: ParsedJD`, `apiKey: string` |
| @State | `currentQuestion: InterviewQuestion`, `round: number`, `answer: string`, `qaHistory: QAPair[]` |
| 主要交互 | 展示题目 → 用户输入回答 → 提交 → LLM 追问（最多三轮）→ 生成 Report |
| 出口 | 三轮完成后 `router.replaceUrl({ url: 'pages/Report', params: { report, qaHistory, jd } })` |

### Report.ets（反馈报告页 — 待创建）

| 特性 | 说明 |
|---|---|
| 路由路径 | `pages/Report` |
| 接收参数 | `report: InterviewReport`, `qaHistory: QAPair[]`, `jd: ParsedJD` |
| @State | `report: InterviewReport` |
| 主要交互 | 展示三维度评分+建议 → "再来一次" 按钮 → `router.back()` |
| 出口 | 返回首页 |

---

## 5. LLM API 契约（外部接口）

### 请求格式

```http
POST {llmEndpoint}
Authorization: Bearer {apiKey}
Content-Type: application/json

{
  "model": "gpt-4",
  "messages": [
    { "role": "system", "content": "{system_prompt}" },
    { "role": "user", "content": "{user_prompt}" }
  ],
  "temperature": 0.7,
  "max_tokens": 2000
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
  ]
}
```

### LLM 端点配置

| 配置项 | 说明 |
|---|---|
| 默认端点 | 通过 Preferences 可配置（规划中） |
| 模型 | 通过 Preferences 可配置，默认 `gpt-4` |
| 支持接入 | 兼容 OpenAI API 格式的任何 LLM 服务 |

---

## 6. 模块依赖图

```
Index.ets
  ├── utils/PreferencesManager.ets  (hasApiKey, saveApiKey)
  ├── utils/http.ts                 (仅首次检查连接)
  └── router.pushUrl → Interview.ets

Interview.ets
  ├── utils/http.ts                 (LLM 请求)
  ├── utils/prompt.ts               (buildQuestion, buildFollowUp)
  └── router.replaceUrl → Report.ets

Report.ets
  ├── utils/http.ts                 (LLM 评分请求)
  ├── utils/prompt.ts               (buildReport)
  └── router.back → Index.ets
```

各页面**禁止直接 import 系统 API**（`@ohos.net.http`、`@ohos.data.preferences`），所有系统级操作统一经过 `utils/` 层。
