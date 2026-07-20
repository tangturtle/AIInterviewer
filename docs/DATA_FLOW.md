# AIInterviewer 数据流与状态管理

## 1. 完整面试流程数据流

```
用户打开应用
       │
       ▼
┌────────────────────────────────────────────────────────────┐
│                 EntryAbility.ets (应用入口)                  │
│  → determineStartPage() → 始终返回 'pages/App'             │
│  → 实际 API Key 检查在 Index.ets 的 aboutToAppear 中异步处理 │
└────────────────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────────┐
│                    Setting.ets (配置页)                      │
│  → 选择供应商（DeepSeek / OpenAI）                          │
│  → 输入 API Key → 检测连通性（testConnection）              │
│  → 获取模型列表（fetchModels）→ 选择模型                    │
│  → 查询余额（fetchBalance，仅DeepSeek）                     │
│  → 点击确认 → saveApiKey + saveProvider + saveModel        │
│  → 800ms 延迟 → navStack.pop()                             │
└────────────────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────────┐
│                 Index.ets (首页)                             │
│  → 用户粘贴/输入 JD 文本                                    │
│  → 检查 API Key（无则自动跳转 Setting）                       │
│  → navStack.pushPath({                                      │
│       name: 'Interview',                                    │
│       param: { jdText }                                     │
│     })                                                      │
└────────────────────────────────────────────────────────────┘
       │
       ▼ (传参: jdText)
┌────────────────────────────────────────────────────────────┐
│              Interview.ets (面试答题) — 7 态状态机            │
│                                                             │
│  状态: loading_jd                                           │
│  ┌─────────────────────────────────────────────┐            │
│  │ callLLM(apiKey, systemPrompt,               │            │
│  │   buildJDPrompt(jdText))                    │            │
│  │ → parseJDResponse() → ParsedJD              │            │
│  └─────────────────────────────────────────────┘            │
│       │ (成功)                                               │
│       ▼                                                    │
│  状态: loading_question                                     │
│  ┌─────────────────────────────────────────────┐            │
│  │ callLLM(apiKey, systemPrompt,               │            │
│  │   buildQuestionPrompt(jd, round=1))         │            │
│  │ → parseQuestionResponse() → Question        │            │
│  └─────────────────────────────────────────────┘            │
│       │ (成功)                                               │
│       ▼                                                    │
│  状态: awaiting_answer                                      │
│  ┌─────────────────────────────────────────────┐            │
│  │ 显示题目 → 用户输入回答 → 点击提交           │            │
│  └─────────────────────────────────────────────┘            │
│       │ (用户提交)                                            │
│       ▼ (循环 3 轮)                                          │
│  状态: loading_followup                                      │
│  ┌─────────────────────────────────────────────┐            │
│  │ callLLM(apiKey, systemPrompt,               │            │
│  │   buildFollowUpPrompt(q, answer, history))  │            │
│  └─────────────────────────────────────────────┘            │
│       │ (成功)                                               │
│       ▼                                                    │
│  状态: awaiting_followup_answer                             │
│  ┌─────────────────────────────────────────────┐            │
│  │ 显示追问 → 用户输入回答 → 点击提交           │            │
│  │ 循环 3 轮后 → 进入 loading_report           │            │
│  └─────────────────────────────────────────────┘            │
│       │ (3 轮完成)                                            │
│       ▼                                                    │
│  状态: loading_report                                        │
│  ┌─────────────────────────────────────────────┐            │
│  │ callLLM(apiKey, systemPrompt,               │            │
│  │   buildReportPrompt(qaHistory, jd))         │            │
│  │ → parseReportResponse() → Report            │            │
│  └─────────────────────────────────────────────┘            │
│       │ (成功)                                               │
│       ▼                                                    │
│  → navStack.replacePath({                                    │
│       name: 'Report',                                        │
│       param: { reportJson: JSON.stringify(report) }          │
│     })                                                      │
│                                                             │
│  任一阶段失败（非 2xx / 解析失败）→ error 状态                │
│  → 最多重试 2 次                                            │
│  → 仍失败 → 显示错误提示 + 返回首页                          │
└────────────────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────────┐
│              Report.ets (反馈报告)                            │
│  → 从 reportJson 解析 InterviewReport                       │
│  → 展示总分 + 三维度（技术/表达/逻辑）评分 + 评语 + 建议     │
│  → "再来一次" → navStack.pop() → Index                      │
└────────────────────────────────────────────────────────────┘
```

## 2. 关键数据对象生命周期

### apiKey / provider / model（持久化配置）

```
创建: Setting.ets → saveApiKey() + saveProvider() + saveModel()
读取: Index.ets / Interview.ets → getApiKey() + getProvider() + getModel()
持久化: Preferences（应用私有目录）
销毁: 用户手动清除或卸载应用
```

### ParsedJD（JD 解析结果）

```
创建: Interview.ets loading_jd 阶段（callLLM → parseJDResponse）
使用: Interview.ets 全流程（生成题目、追问、评分）
传递: Interview.ets @State → 仅面试页使用（不跨页传 ParsedJD）
销毁: 面试结束或页面销毁
```

### QAPair[]（问答历史）

```
创建: Interview.ets loading_question 阶段（首轮题目生成后初始化）
追加: 每轮用户回答 + 追问回答
使用: Interview.ets loading_followup 追问 → loading_report 评分
传递: Interview.ets @State（不跨页传，Report 使用评分结果）
销毁: 面试结束或页面销毁
```

### InterviewReport（评分报告）

```
创建: Interview.ets loading_report 阶段（callLLM → parseReportResponse）
使用: Report.ets 渲染
传递: NavPathInfo.param（JSON.stringify 序列化后传递）
持久化: 规划中（本地留存面试记录）
```

## 3. 状态管理策略

### 当前方案：@State 局部状态

ArkUI 声明式 `@State` 装饰器，每个页面独立管理自己的状态。

```typescript
// Index.ets
@State jdText: string = '';
@State hasKey: boolean = false;
@State selectedModel: string = '';
@State modelOptions: SelectOption[] = [];
@State modelIndex: number = 0;
@State balanceInfo: string = '';
@State connectionStatus: string = '';
@State statusType: string = '';

// Interview.ets — 7 态状态机（pageState 使用字符串字面量）
@State pageState: string = 'loading_jd';
@State parsedJD: ParsedJD | null = null;
@State currentRound: number = 1;
@State currentQuestion: InterviewQuestion | null = null;
@State currentAnswer: string = '';
@State followUpQuestion: string = '';
@State followUpAnswer: string = '';
@State qaHistory: QAPair[] = [];
@State errorMessage: string = '';
@State retryCount: number = 0;

// Report.ets
@State report: InterviewReport | null = null;

// Setting.ets
@State providerIndex: number = 0;
@State apiKeyInput: string = '';
@State testResult: string = '';
@State isTesting: boolean = false;
@State balanceInfo: string = '';
@State modelOptions: SelectOption[] = [];
@State modelIndex: number = 0;
@State selectedModel: string = '';
@State savedFeedback: boolean = false;
@State isApiFocused: boolean = false;
```

### 跨页面数据传递：NavPathStack + NavPathInfo

```typescript
// Index → Interview
this.navStack.pushPath({
  name: 'Interview',
  param: { jdText: this.jdText }
});

// Interview → Report
this.navStack.replacePath({
  name: 'Report',
  param: { reportJson: JSON.stringify(this.report) }
});

// Setting → Index
this.navStack.pop();
```

页面通过 `NavDestination` 的 `onReady` 回调接收参数：

```typescript
.onReady((context: NavDestinationContext) => {
  if (context?.pathInfo?.param) {
    this.params = context.pathInfo.param as Record<string, Object>;
  }
});
```

### 未来可选：@Provide / @Consume

如果页面组件树变深（如弹窗、子组件），可以用 `@Provide` / `@Consume` 替代 prop drilling。

## 4. 异步操作流

```
用户触发操作
       │
       ▼
  pageState = loading_xxx  (更新 UI 为加载态)
       │
       ▼
  await callLLM(apiKey, prompt...)  (LLM 请求)
       │
       │  成功               │  失败 & 可重试        │  失败 & 不可重试
       ▼                     ▼                       ▼
  解析数据               retryCount++              pageState = error
  pageState = 下一态      重试请求                   显示错误提示
  更新 UI                 (最多 2 次)               返回首页
```

**错误类型与处理策略：**

| 错误场景 | 处理方式 |
|---|---|
| 网络不可用（超时 / DNS 失败） | 提示"网络连接失败"→ 重试（最多 2 次）|
| API Key 无效（401） | 提示"API Key 无效"→ 跳转 Setting 重新配置 |
| LLM 返回格式异常（JSON 解析失败） | 提示"解析失败"→ 重试（最多 2 次） |
| API 错误码（400/500） | 提示"服务异常"→ 重试（最多 2 次） |
| 页面被系统回收 | 所有 @State 数据丢失，需重新开始 |

## 5. 缓存与持久化

| 数据类型 | 存储方式 | 生命周期 |
|---|---|---|
| API Key | Preferences（`saveApiKey`） | 持久化，用户手动清除或覆盖 |
| 供应商名 | Preferences（`saveProvider`） | 持久化 |
| 模型名 | Preferences（`saveModel`） | 持久化 |
| 连接测试缓存（模型列表/余额/测试结果） | Preferences（`saveTestCache`） | 持久化，供应商/Key 变更时清除 |
| 面试记录 | Preferences（规划中） | 持久化，可查看历史 |
| JD 解析缓存 | @State（Interview.ets） | 面试页面生命周期 |
| 问答历史 | @State → NavPathInfo param | 面试→报告传递后释放 |
| LLM 请求响应 | 无缓存（每次请求独立） | 用完即弃 |

## 6. 性能与鸿蒙特性规划

### 流式输出（Phase 3 规划）

长 LLM 响应使用 `@ohos.net.http` 的 `on('dataReceive')` 事件逐步渲染：

```typescript
// 伪代码 — 实现时参考
const request = http.createHttp();
request.on('dataReceive', (data: ArrayBuffer) => {
  this.streamingText += decoder.decode(data);
});
request.request(url, { method: http.RequestMethod.POST, ... });
```

### 分布式数据对象（Phase 3 规划）

面试进度可通过 `@ohos.data.distributedDataObject` 在手机和平板间同步：

```typescript
// 伪代码
import { distributedDataObject } from '@kit.ArkData';
const session = distributedDataObject.create(this.context, {
  currentRound: 0,
  qaHistory: []
});
```
