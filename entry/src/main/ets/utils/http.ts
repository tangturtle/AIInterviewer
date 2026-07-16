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
      expectDataType: http.HttpDataType.STRING
    });
    return response.result as string;
  } finally {
    httpRequest.destroy();
  }
}
