import { http } from '@kit.NetworkKit';

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
    return response.result as string;
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 测试 API 连通性
 * 发送一个简单请求到 LLM 端点，验证 API Key 和网络是否可用
 * @param apiKey - API Key
 * @param endpoint - LLM API 端点
 * @returns 连通成功返回 true，失败返回 false
 */
export async function testConnection(apiKey: string, endpoint: string): Promise<boolean> {
  const httpRequest = http.createHttp();
  try {
    const body = {
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: 'Hi' }],
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
    const respCode = response.responseCode;
    return respCode >= 200 && respCode < 500;
  } catch (err) {
    return false;
  } finally {
    httpRequest.destroy();
  }
}
