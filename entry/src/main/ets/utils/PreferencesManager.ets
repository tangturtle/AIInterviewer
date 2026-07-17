import { preferences } from '@kit.ArkData';

const STORE_NAME = 'ai_interviewer_prefs';
const KEY_API_KEY = 'llm_api_key';

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
