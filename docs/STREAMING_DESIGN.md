# 流式输出设计文档

> Phase 3.1 — LLM 响应边收边渲染，替代全量等待

## 1. 目标

将当前全量等待 LLM 响应的模式（`callLLM` → 一次性返回）升级为流式模式，使用 `@ohos.net.http` 的 `onDataReceive` 回调解析 SSE 数据块，实现逐字/逐句渲染。**所有 LLM 调用均前台实时渲染**。

## 2. 架构改动

```
改动前：
  Interview.ets → callLLM() → http.ts:post() → 全量响应 → parse → 渲染

改动后：
  Interview.ets → callLLMStream(onDelta) → http.ts:streamPost()
    → onDataReceive → SSE 解析 → onDelta(content) → 实时渲染
    → onDone → parse(完整JSON) → 状态转换
```

## 3. 网络层 — http.ts

### 3.1 SSE 解析器

```typescript
class SSESplitter {
  private buffer: string = '';

  /** 处理 onDataReceive 的 ArrayBuffer 数据 */
  feed(data: ArrayBuffer): Array<{ content: string; reasoningContent?: string; finishReason?: string }> {
    // 1. 将 ArrayBuffer 转为字符串，追加到 buffer
    // 2. 按 \n\n 分割完整 SSE 事件
    // 3. 对每个完整事件提取 data: 行
    // 4. 解析 JSON，提取 delta.content / delta.reasoning_content / finish_reason
    // 5. 未完成的行留在 buffer 中
  }
}
```

### 3.2 streamPost

```typescript
interface StreamCallbacks {
  onContent: (text: string) => void;          // 每次收到 content delta
  onReasoning: (text: string) => void;         // DeepSeek 思考过程文本
  onFinishReason: (reason: string) => void;     // stop / length
  onError: (err: Error) => void;
  onDone: () => void;
}

/** 流式 POST，返回 HttpRequest 以便外部取消 */
function streamPost(
  url: string,
  body: object,
  apiKey: string,
  callbacks: StreamCallbacks
): http.HttpRequest {
  // 1. createHttp()
  // 2. on('dataReceive') → sseSplitter.feed(data) → callbacks
  // 3. on('dataEnd') → callbacks.onDone()
  // 4. request(url, { method: POST, stream: true 的 body })
  // 5. 返回 httpRequest（外部可 destroy() 取消）
}
```

body 中添加 `stream: true` 参数。超时：connectTimeout=15s, readTimeout=60s（流式通道需更长读超时）。

## 4. 提示词层 — prompt.ts

新增 `callLLMStream()`：

```typescript
function callLLMStream(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string,
  callbacks: {
    onContent: (fullText: string) => void;       // 实时 delta 累计
    onReasoning?: (text: string) => void;         // DeepSeek 思考过程
    onComplete: (fullContent: string) => void;     // 流结束，返回完整文本
    onError: (err: Error) => void;
  },
  endpoint?: string,
  model?: string
): http.HttpRequest
```

- `onContent` 回调每次 delta 到达时触发，传**累计完整文本**
- JSON 模式响应（出题/评分/JD）：`onComplete` 后调用 `parse*Response()` 解析
- 纯文本（追问）：`onContent` 可直接增量渲染
- 返回 `HttpRequest` 以便 `destroy()` 取消

现有 `callLLM()` 保留不变（用于 Setting 页连通测试等非流式场景）。

## 5. UI 层 — Interview.ets

### 5.1 新增状态

```typescript
@State streamingText: string = '';         // 累计的流式文本
@State streamingReasoning: string = '';    // DeepSeek 思考过程
private currentStreamRequest: http.HttpRequest | null = null;  // 用于取消
```

### 5.2 状态机变更

```
原: loading_* → (awaiting_answer | awaiting_followup_answer | report)
新: loading_* → streaming → (awaiting_answer | awaiting_followup_answer | report)
```

| 原状态 | 流式期间状态 | 完成后 |
|--------|-------------|--------|
| `loading_jd` | `streaming` (显示流式 JSON) | → 解析后进入 `loading_question` |
| `loading_question` | `streaming` (显示流式 JSON) | → 解析后进入 `awaiting_answer` |
| `loading_followup` | `streaming` (显示实时追问文本) | → 解析后进入 `awaiting_followup_answer` |
| `loading_report` | `streaming` (显示流式 JSON) | → 解析后 `replacePath` 到 Report |

### 5.3 StreamingView 组件

```typescript
@Builder
StreamingView(): void {
  Column() {
    // DeepSeek 思考过程（灰色小字）
    if (this.streamingReasoning) {
      Text(this.streamingReasoning)
        .fontSize(12).fontColor($r('app.color.text_tip'))
        .backgroundColor($r('app.color.card_background_light'))
        .padding(12).borderRadius(8).width('100%');
    }

    // 流式内容（逐字递增）
    Text(this.streamingText)
      .fontSize(16).fontColor($r('app.color.text_primary'))
      .lineHeight(26).width('100%');

    // 闪烁光标指示器
    Text('▊')
      .fontSize(16).fontColor($r('app.color.primary'))
      .opacity(this.cursorVisible ? 1 : 0);
  }
}
```

### 5.4 JSON 处理

- 出题 / JD 解析 / 评分报告：`onComplete` 后调用 `parse*Response()` 解析完整文本
- 追问：`onContent` 回调中直接更新 `streamingText`，用户看到实时追问文字

## 6. 面试流程改动

```typescript
private async parseJD(): Promise<void> {
  this.pageState = 'loading_jd';  // 短暂显示后即进入 streaming
  this.callLLMStream(...);
}

private async generateQuestion(): Promise<void> {
  this.pageState = 'loading_question';
  this.callLLMStream(..., {
    onContent: (text) => { this.streamingText = text; this.pageState = 'streaming'; },
    onComplete: (full) => {
      const q = parseQuestionResponse(await reconstructResponse(full));
      if (q) { this.currentQuestion = q; this.pageState = 'awaiting_answer'; }
    }
  });
}
```

> `reconstructResponse()` 将流式累积的 `content` 重新包裹成 LLM 响应结构，供 `parse*Response()` 解析。

## 7. DeepSeek 思考模式处理

DeepSeek 默认启用思考模式，SSE 事件顺序：

```
1. data: {"choices":[{"delta":{"role":"assistant","reasoning_content":"正在思考..."}}]}
2. data: {"choices":[{"delta":{"content":"最终回答"}}]}
3. data: {"choices":[{"delta":{},"finish_reason":"stop"}]}
```

- `reasoning_content` 通过 `onReasoning` 单独回调，UI 用灰色小字显示"思考中..."
- `content` 正常通过 `onContent` 增量渲染

## 8. 错误与取消

- **取消**：用户离开页面时调用 `currentStreamRequest?.destroy()` 中断请求
- **超时**：`readTimeout: 60000`（60秒），超时时 `onError` 被触发
- **重试**：`callWithRetry` 保持不变，只是在流式模式下需要先 destroy 当前请求再重试

## 9. 文件变更清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `utils/http.ts` | 新增 | `SSESplitter` 类 + `streamPost()` 函数 + `StreamCallbacks` 接口 |
| `utils/prompt.ts` | 新增 | `callLLMStream()` 函数 |
| `pages/Interview.ets` | 修改 | 状态机扩展 + StreamingView + 流式回调逻辑 |

不影响：`Setting.ets`、`Index.ets`、`Report.ets`、`PreferencesManager.ets`、`types.ts`
