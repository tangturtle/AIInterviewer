import { util } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';

// ── SSE (Server-Sent Events) 流式输出 ───────────────────────

/** 流式回调接口 */
export interface StreamCallbacks {
  /** 每次收到 content delta */
  onContent: (text: string) => void;
  /** DeepSeek 思考过程文本（可选） */
  onReasoning?: (text: string) => void;
  /** 流结束原因（stop / length） */
  onFinishReason?: (reason: string) => void;
  /** 发生错误 */
  onError: (err: Error) => void;
  /** 流正常结束 */
  onDone: () => void;
}

/**
 * SSE 数据解析器，处理跨 chunk 边界的行缓冲
 */
export class SSESplitter {
  private buffer: string = '';

  /**
   * 向解析器喂入原始二进制数据
   * @param data - onDataReceive 接收的 ArrayBuffer
   * @returns 解析出的 SSE 事件数组
   */
  feed(data: ArrayBuffer): Array<{ content: string; reasoningContent?: string; finishReason?: string }> {
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const chunk = decoder.decodeToStringSync(data);
    this.buffer += chunk;

    const results: Array<{ content: string; reasoningContent?: string; finishReason?: string }> = [];
    const parts = this.buffer.split('\n\n');

    // 最后一个部分可能不完整，留在 buffer 中
    this.buffer = parts.pop() || '';

    for (const part of parts) {
      for (const line of part.split('\n')) {
        if (line.startsWith('data: ')) {
          const jsonStr = line.slice(6).trim();
          if (jsonStr === '[DONE]') { continue; }
          try {
            const parsed = JSON.parse(jsonStr);
            const delta = parsed?.choices?.[0]?.delta;
            const finishReason = parsed?.choices?.[0]?.finish_reason;
            if (delta || finishReason) {
              const evt: { content: string; reasoningContent?: string; finishReason?: string } = { content: '' };
              if (delta?.content) { evt.content = delta.content; }
              if (delta?.reasoning_content) { evt.reasoningContent = delta.reasoning_content; }
              if (finishReason) { evt.finishReason = finishReason; }
              if (evt.content || evt.reasoningContent || evt.finishReason) {
                results.push(evt);
              }
            }
          } catch (_err) {
            // 忽略解析失败的行（可能是跨 chunk 的不完整 JSON）
          }
        }
      }
    }
    return results;
  }
}

/**
 * 流式 POST 请求（SSE）
 * @param url - API 端点
 * @param body - 请求体（自动添加 stream: true）
 * @param apiKey - API Key
 * @param callbacks - 流式回调
 * @returns HttpRequest 句柄，可调用 destroy() 取消
 */
export function streamPost(
  url: string,
  body: object,
  apiKey: string,
  callbacks: StreamCallbacks
): http.HttpRequest {
  const httpRequest = http.createHttp();
  const splitter = new SSESplitter();
  let hasError = false;

  httpRequest.on('dataReceive', (data: ArrayBuffer): void => {
    const events = splitter.feed(data);
    for (const evt of events) {
      if (evt.content) { callbacks.onContent(evt.content); }
      if (evt.reasoningContent && callbacks.onReasoning) { callbacks.onReasoning(evt.reasoningContent); }
      if (evt.finishReason && callbacks.onFinishReason) { callbacks.onFinishReason(evt.finishReason); }
    }
  });

  httpRequest.on('dataEnd', (): void => {
    hasError = true;
    callbacks.onDone();
  });

  httpRequest.on('dataError', (_error: number): void => {
    if (!hasError) {
      hasError = true;
      callbacks.onError(new Error('SSE 数据接收错误'));
    }
  });

  const requestBody = JSON.stringify({ ...body, stream: true });

  httpRequest.request(url, {
    method: http.RequestMethod.POST,
    header: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + apiKey
    },
    extraData: requestBody,
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: 15000,
    readTimeout: 60000
  }).catch((err: Error): void => {
    if (!hasError) {
      hasError = true;
      callbacks.onError(err);
    }
  });

  return httpRequest;
}

export async function post(url: string, body: object, apiKey: string): Promise<string> {
  const httpRequest = http.createHttp();
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + apiKey
      },
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000
    });
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('API 返回错误码: ' + response.responseCode);
    }
    return response.result as string;
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 测试 API 连通性（通过 POST 最小请求检查认证和网络）
 * @param apiKey - API Key
 * @param endpoint - LLM API 端点
 * @param model - 模型名（可选，默认自动检测）
 */
export async function testConnection(apiKey: string, endpoint: string, model: string = 'deepseek-v4-flash'): Promise<boolean> {
  const httpRequest = http.createHttp();
  try {
    const body = {
      model: model,
      messages: [{ role: 'user', content: 'hi' }],
      max_tokens: 5,
      temperature: 0
    };
    const response = await httpRequest.request(endpoint, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + apiKey
      },
      extraData: JSON.stringify(body),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 15000
    });
    return response.responseCode < 400;
  } catch (err) {
    return false;
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 从 chat/completions 端点推导模型列表 URL
 */
function getModelsUrl(endpoint: string): string {
  const suffix = '/chat/completions';
  if (endpoint.endsWith(suffix)) {
    // deepseek: https://api.deepseek.com/chat/completions -> https://api.deepseek.com/models
    // openai:   https://api.openai.com/v1/chat/completions -> https://api.openai.com/v1/models
    return endpoint.substring(0, endpoint.length - suffix.length) + '/models';
  }
  const idx = endpoint.indexOf('/v1/');
  if (idx > 0) {
    return endpoint.substring(0, idx) + '/v1/models';
  }
  return endpoint + '/models';
}

/**
 * 获取可用模型列表
 * @param apiKey - API Key
 * @param endpoint - LLM API 端点（用于提取模型列表 URL）
 * @returns 模型 ID 数组，失败返回空数组
 */
export async function fetchModels(apiKey: string, endpoint: string): Promise<string[]> {
  const url = getModelsUrl(endpoint);
  const httpRequest = http.createHttp();
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Authorization': 'Bearer ' + apiKey
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 15000
    });
    if (response.responseCode !== 200) {
      return [];
    }
    const data = JSON.parse(response.result as string);
    const models: string[] = [];
    if (data && data.data && Array.isArray(data.data)) {
      for (let i = 0; i < data.data.length; i++) {
        const m = data.data[i];
        if (m.id && typeof m.id === 'string') {
          models.push(m.id);
        }
      }
    }
    return models;
  } catch (err) {
    return [];
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 查询 DeepSeek 账户余额
 * @param apiKey - API Key
 * @returns 余额描述字符串，失败返回空字符串
 */
export async function fetchBalance(apiKey: string): Promise<string> {
  const url = 'https://api.deepseek.com/user/balance';
  const httpRequest = http.createHttp();
  try {
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Authorization': 'Bearer ' + apiKey
      },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 10000,
      readTimeout: 15000
    });
    if (response.responseCode !== 200) {
      return '';
    }
    const data = JSON.parse(response.result as string);
    if (data && data.is_available !== undefined && data.balance_infos) {
      const infos = data.balance_infos;
      if (infos.length > 0) {
        const info = infos[0];
        const currency = info.currency || 'CNY';
        const total = info.total_balance || '0';
        return '余额: ' + total + ' ' + currency + (data.is_available ? ' (可用)' : ' (不可用)');
      }
    }
    return '';
  } catch (err) {
    return '';
  } finally {
    httpRequest.destroy();
  }
}
