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
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('API 返回错误码: ' + response.responseCode);
    }
    return response.result as string;
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 测试 API 连通性
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
    return respCode >= 200 && respCode < 300;
  } catch (err) {
    return false;
  } finally {
    httpRequest.destroy();
  }
}

/**
 * 获取 API 供应商的基 URL（从完整端点中提取）
 */
function getBaseUrl(endpoint: string): string {
  const idx = endpoint.indexOf('/v1/');
  if (idx > 0) {
    return endpoint.substring(0, idx);
  }
  return endpoint;
}

/**
 * 获取可用模型列表
 * @param apiKey - API Key
 * @param endpoint - LLM API 端点（用于提取基 URL）
 * @returns 模型 ID 数组，失败返回空数组
 */
export async function fetchModels(apiKey: string, endpoint: string): Promise<string[]> {
  const baseUrl = getBaseUrl(endpoint);
  const url = baseUrl + '/v1/models';
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
