/**
 * AIInterviewer 分布式数据同步模块
 *
 * 基于 @ohos.data.distributedDataObject 实现手机→平板面试进度同步。
 * 通过 Preferences 开关控制启用/禁用，默认关闭。
 */
import distributedDataObject from '@ohos.data.distributedDataObject';
import { preferences } from '@kit.ArkData';

const STORE_NAME = 'ai_interviewer_prefs';
const KEY_DISTRIBUTED_ENABLED = 'ai_interviewer_distributed_enabled';

let _pref: preferences.Preferences | null = null;

async function getPref(context: Context): Promise<preferences.Preferences> {
  if (!_pref) {
    _pref = await preferences.getPreferences(context, STORE_NAME);
  }
  return _pref;
}

/** 跨设备同步的面试数据载荷（轻量，不含完整 qaHistory） */
export interface InterviewSyncData {
  currentRound: number;
  pageState: string;
  jdText: string;
  reportJson: string;
}

/** 分布式开关 — 保存 */
export async function saveDistributedEnabled(context: Context, enabled: boolean): Promise<void> {
  const store = await getPref(context);
  await store.put(KEY_DISTRIBUTED_ENABLED, enabled);
  await store.flush();
}

/** 分布式开关 — 读取 */
export async function getDistributedEnabled(context: Context): Promise<boolean> {
  const store = await getPref(context);
  return (await store.get(KEY_DISTRIBUTED_ENABLED, false)) as boolean;
}

/**
 * 创建分布式数据对象 Session
 * 仅在主设备（Interview 页）调用
 */
export async function createDistributedSession(context: Context): Promise<object | null> {
  try {
    const dataObj: object = distributedDataObject.create(context, {
      currentRound: 0,
      pageState: '',
      jdText: '',
      reportJson: ''
    });
    return dataObj;
  } catch (err) {
    const em = (err as Error).message;
    if (em.length > 0) { return null; }
    return null;
  }
}

/**
 * 增量更新分布式对象字段
 */
export function updateSyncField(dataObj: object | null, key: string, value: Object): void {
  if (!dataObj) { return; }
  try {
    (dataObj as Record<string, Object>)[key] = value;
  } catch (err) {
    const em = (err as Error).message;
    if (em.length > 0) { /* 静默失败 */ }
  }
}

/**
 * 读取分布式对象字段
 */
export function getSyncField(dataObj: object | null, key: string): Object | null {
  if (!dataObj) { return null; }
  try {
    return (dataObj as Record<string, Object>)[key];
  } catch (err) {
    const em = (err as Error).message;
    if (em.length > 0) { return null; }
    return null;
  }
}
