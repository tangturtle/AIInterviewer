# AIInterviewer 数据流与状态管理

## 1. 完整面试流程数据流

```
用户输入 JD 文本
       │
       ▼
┌─────────────────────────────────────────────────┐
│                 Index.ets (首页)                  │
│  → 用户粘贴/输入 JD 文本                           │
│  → 检查 hasApiKey()                              │
│     ├── false → 弹窗输入 API Key → saveApiKey()  │
│     └── true  → 继续                             │
│  → router.pushUrl({                              │
│       url: 'pages/Interview',                    │
│       params: { jdText, apiKey }                 │
│     })                                           │
└─────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│              Interview.ets (面试答题)             │
│                                                 │
│  第 1 步: LLM 解析 JD                             │
│  ┌─────────────────────────────────────┐         │
│  │ http.post(LLM, buildJDPrompt(jd))   │         │
│  │ → parseJDResponse() → ParsedJD      │         │
│  └─────────────────────────────────────┘         │
│       │                                         │
│       ▼                                         │
│  第 2 步: LLM 生成面试题（第 1 轮）               │
│  ┌─────────────────────────────────────┐         │
│  │ http.post(LLM, buildQuestionPrompt( │         │
│  │   parsedJD, round=1))              │         │
│  │ → parseQuestionResponse()          │         │
│  │ → display question                 │         │
│  └─────────────────────────────────────┘         │
│       │                                         │
│       ▼                                         │
│  第 3 步: 用户回答 + LLM 追问                     │
│  ┌─ 循环最多 3 轮 ─────────────────────┐         │
│  │ 用户输入回答 → 存 qaHistory        │         │
│  │ http.post(LLM, buildFollowUpPrompt( │         │
│  │   question, answer, history))       │         │
│  │ → 展示追问 → 用户回答 → 存 history │         │
│  └─────────────────────────────────────┘         │
│       │                                         │
│       ▼                                         │
│  第 4 步: LLM 生成评分报告                        │
│  ┌─────────────────────────────────────┐         │
│  │ http.post(LLM, buildReportPrompt(   │         │
│  │   qaHistory, parsedJD))             │         │
│  │ → parseReportResponse() → Report    │         │
│  └─────────────────────────────────────┘         │
│       │                                         │
│       ▼                                         │
│  → router.replaceUrl({                           │
│       url: 'pages/Report',                       │
│       params: { report, qaHistory, jd }          │
│     })                                           │
└─────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│              Report.ets (反馈报告)                │
│  → 展示三维度评分 + 建议                        │
│  → "再来一次" → router.back() → Index          │
└─────────────────────────────────────────────────┘
```

## 2. 关键数据对象生命周期

### ParsedJD（JD 解析结果）

```
创建: Interview.ets 第 1 步（LLM 返回 → parseJDResponse）
使用: Interview.ets 全流程（生成题目、追问、评分）
传递: Interview.ets @State → pushUrl params → Report.ets
销毁: 用户退出报告页后（页面销毁）
```

### QAPair[]（问答历史）

```
创建: Interview.ets 第 2 步（首轮题目生成后初始化）
追加: 每轮用户回答 + 追问回答
使用: Interview.ets 第 3 步追问 → 第 4 步评分
传递: Interview.ets @State → replaceUrl params → Report.ets
销毁: 用户退出报告页后
```

### InterviewReport（评分报告）

```
创建: Interview.ets 第 4 步（LLM 返回 → parseReportResponse）
使用: Report.ets 渲染
传递: replaceUrl params（仅读取）
持久化: 规划中（本地留存面试记录）
```

## 3. 状态管理策略

### 当前方案：@State 局部状态

ArkUI 声明式 `@State` 装饰器，每个页面独立管理自己的状态。

```typescript
// Index.ets
@State jdText: string = '';

// Interview.ets（待创建）
@State currentQuestion: InterviewQuestion;
@State round: number = 0;
@State answer: string = '';
@State qaHistory: QAPair[] = [];
@State loading: boolean = false;

// Report.ets（待创建）
@State report: InterviewReport;
```

### 跨页面数据传递：router params

```typescript
// Index → Interview
router.pushUrl({
  url: 'pages/Interview',
  params: { jdText: this.jdText, apiKey: await getApiKey(ctx) }
});

// Interview → Report
router.replaceUrl({
  url: 'pages/Report',
  params: { report: this.report, qaHistory: this.qaHistory, jd: this.parsedJD }
});
```

Report.ets 通过 `@State report: InterviewReport = router.getParams()?.report as InterviewReport` 接收。

### 未来可选：@Provide / @Consume

如果页面组件树变深（如弹窗、子组件），可以用 `@Provide` / `@Consume` 替代 prop drilling。

## 4. 异步操作流

```
用户触发操作
       │
       ▼
  set loading = true
       │
       ▼
  await http.post() ... (LLM 请求)
       │
       │  成功          │  失败
       ▼                ▼
  解析数据            显示错误提示
  set loading = false  set loading = false
  更新 UI             可选重试
```

**错误类型与处理策略：**

| 错误场景 | 处理方式 |
|---|---|
| 网络不可用 | 提示"网络连接失败，请检查网络设置" |
| API Key 无效 | 提示"API Key 无效，请重新配置"→ 跳转回首页 |
| LLM 返回格式异常 | 提示"解析失败，请重试"→ 重新请求（最多重试 2 次） |
| 超时 | 提示"请求超时，请重试" |
| 页面被系统回收 | 数据保存在局部状态中丢失，需重新开始面试 |

## 5. 缓存与持久化规划

| 数据类型 | 存储方式 | 生命周期 |
|---|---|---|
| API Key | Preferences | 持久化，用户手动清除 |
| 面试记录 | Preferences（规划） | 持久化，可查看历史 |
| JD 解析缓存 | @State | 页面生命周期 |
| 问答历史 | @State → router params | 首次 render 后释放 |
| LLM 请求响应 | 无缓存（每次请求独立） | 用完即弃 |

## 6. 性能与鸿蒙特性规划

### 流式输出（规划中）

长 LLM 响应使用 `@ohos.net.http` 的 `on('dataReceive')` 事件逐步渲染：

```typescript
// 伪代码 — 实现时参考
const request = http.createHttp();
request.on('dataReceive', (data: ArrayBuffer) => {
  // 逐步追加到显示文本
  this.streamingText += decoder.decode(data);
});
request.request(url, { method: http.RequestMethod.POST, ... });
```

### 分布式数据对象（规划）

面试进度可通过 `@ohos.data.distributedDataObject` 在手机和平板间同步：

```typescript
// 伪代码
import { distributedDataObject } from '@kit.ArkData';
const session = distributedDataObject.create(this.context, {
  currentRound: 0,
  qaHistory: []
});
```
