import { preferences } from '@kit.ArkData';

const STORE_NAME = 'ai_interviewer_prefs';
const KEY_API_KEY = 'ai_interviewer_api_key';
const KEY_ENDPOINT = 'ai_interviewer_endpoint';
const KEY_MODEL = 'ai_interviewer_model';

/** 内置 API 供应商端点 */
export const BUILTIN_ENDPOINTS: Record<string, string> = {
  'openai': 'https://api.openai.com/v1/chat/completions',
  'deepseek': 'https://api.deepseek.com/v1/chat/completions'
};

/** 各供应商的默认模型 */
export const DEFAULT_MODELS: Record<string, string> = {
  'openai': 'gpt-4',
  'deepseek': 'deepseek-chat'
};
export const DEFAULT_PROVIDER = 'deepseek';

let _pref: preferences.Preferences | null = null;

async function getStore(context: Context): Promise<preferences.Preferences> {
  if (!_pref) {
    _pref = await preferences.getPreferences(context, STORE_NAME);
  }
  return _pref;
}

export async function saveApiKey(context: Context, key: string): Promise<void> {
  const store = await getStore(context);
  await store.put(KEY_API_KEY, key);
  await store.flush();
}

export async function getApiKey(context: Context): Promise<string | null> {
  const store = await getStore(context);
  const val = await store.get(KEY_API_KEY, '') as string;
  return val || null;
}

export async function hasApiKey(context: Context): Promise<boolean> {
  const key = await getApiKey(context);
  return key !== null && key.length > 0;
}

/** 保存 API 供应商名称（如 'openai', 'deepseek'） */
export async function saveProvider(context: Context, provider: string): Promise<void> {
  const store = await getStore(context);
  await store.put(KEY_ENDPOINT, provider);
  await store.flush();
}

/** 读取 API 供应商名称，未设置返回默认值 */
export async function getProvider(context: Context): Promise<string> {
  const store = await getStore(context);
  const val = await store.get(KEY_ENDPOINT, '') as string;
  return val || DEFAULT_PROVIDER;
}

/** 获取当前供应商的完整 API 端点 URL */
export async function getEndpoint(context: Context): Promise<string> {
  const provider = await getProvider(context);
  return BUILTIN_ENDPOINTS[provider] || BUILTIN_ENDPOINTS[DEFAULT_PROVIDER];
}

/** 保存选中的模型名称 */
export async function saveModel(context: Context, model: string): Promise<void> {
  const store = await getStore(context);
  await store.put(KEY_MODEL, model);
  await store.flush();
}

/** 读取选中的模型名称，未设置返回供应商默认模型 */
export async function getModel(context: Context): Promise<string> {
  const store = await getStore(context);
  const val = await store.get(KEY_MODEL, '') as string;
  if (val) {
    return val;
  }
  const provider = await getProvider(context);
  return DEFAULT_MODELS[provider] || 'deepseek-chat';
}
