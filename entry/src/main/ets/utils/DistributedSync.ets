/**
 * AIInterviewer 分布式数据同步模块
 *
 * 基于 @ohos.data.distributedDataObject 实现手机→平板面试进度同步。
 * 通过 Preferences 开关控制启用/禁用，默认关闭。
 *
 * 使用方式（主设备 Interview 页）：
 *   const session = await createDistributedSession(context);
 *   if (session) {
 *     updateSyncField(session, 'pageState', 'question_ready');
 *     onSessionStatusChange((status) => { this.distributedStatus = status; });
 *   }
 *
 * 使用方式（副设备）：
 *   const session = await createDistributedSession(context);
 *   if (session) {
 *     const state = getSyncField(session, 'pageState');
 *     onRemoteDataChange(session, (dataObj) => {
 *       const newState = getSyncField(dataObj, 'pageState');
 *     });
 *   }
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import distributedDataObject from '@ohos.data.distributedDataObject';
import { preferences } from '@kit.ArkData';

const SESSION_ID = 'ai_interviewer_session';
const SYNC_ALLOWED_KEYS: string[] = ['currentRound', 'pageState', 'jdText', 'reportJson'];

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
  hilog.info(0x0000, 'AIInterviewer', 'dist: saveDistributedEnabled %{public}s', enabled.toString());
  const store = await getPref(context);
  await store.put(KEY_DISTRIBUTED_ENABLED, enabled);
  await store.flush();
}

/** 分布式开关 — 读取 */
export async function getDistributedEnabled(context: Context): Promise<boolean> {
  const store = await getPref(context);
  const val: boolean = (await store.get(KEY_DISTRIBUTED_ENABLED, false)) as boolean;
  hilog.info(0x0000, 'AIInterviewer', 'dist: getDistributedEnabled %{public}s', val.toString());
  return val;
}

/**
 * 创建分布式数据对象 Session
 *
 * 自动配置：
 *  - setSessionId(SESSION_ID) — 同 ID 设备组成同步组
 *  - on('status') — 监听对端设备上线/下线
 *  - on('change') — 监听远端数据变更
 *
 * @param context - UI 上下文（getContext()）
 * @returns 分布式对象句柄，失败返回 null
 */
export async function createDistributedSession(context: Context): Promise<object | null> {
  hilog.info(0x0000, 'AIInterviewer', 'dist: createDistributedSession start');
  try {
    const dataObj: object = distributedDataObject.create(context, {
      currentRound: 0,
      pageState: '',
      jdText: '',
      reportJson: ''
    });

    const dobj: Record<string, Object> = dataObj as Record<string, Object>;

    // 绑定 sessionId — 同 ID 的设备自动互通
    (dobj['setSessionId'] as Function)(SESSION_ID);
    hilog.info(0x0000, 'AIInterviewer', 'dist: session created, sessionId=%{public}s', SESSION_ID);

    // 监听对端上下线
    (dobj['on'] as Function)('status', (statusData: object): void => {
      hilog.info(0x0000, 'AIInterviewer', 'dist: status event raw %{public}s', JSON.stringify(statusData));
      const sd: Record<string, Object> = statusData as Record<string, Object>;
      const status: string = sd['status'] as string;
      const online: boolean = status === 'online';
      _online = online;
      const _status: string = online ? '已连接' : '已断开';
      hilog.info(0x0000, 'AIInterviewer', 'dist: status parsed online=%{public}s text=%{public}s', online.toString(), _status);
      if (_statusCallback) { _statusCallback(_status); }
    });

    // 监听远端数据变更 — 用 _data 而非闭包捕获的 dataObj
    (dobj['on'] as Function)('change', (_data: object): void => {
      hilog.info(0x0000, 'AIInterviewer', 'dist: change event received');
      if (_changeCallback) { _changeCallback(_data); }
    });

    hilog.info(0x0000, 'AIInterviewer', 'dist: createDistributedSession success');

    return dataObj;
  } catch (err) {
    const em: string = (err as Error).message;
    hilog.error(0x0000, 'AIInterviewer', 'createDistributedSession: %{public}s', em);
    if (em.indexOf('already created') >= 0 || em.indexOf('same sessionId') >= 0 || em.indexOf('1652') >= 0) {
      hilog.warn(0x0000, 'AIInterviewer', 'dist: duplicate sessionId — old session may not be released. Try cleanupDistributedSession first.');
    }
    return null;
  }
}

// -- 回调注册（单例，仅支持一个监听者） --
let _online: boolean = false;
let _statusCallback: ((status: string) => void) | null = null;
let _changeCallback: ((dataObj: object) => void) | null = null;

/** 查询当前对端是否在线 */
export function getSessionOnline(): boolean {
  return _online;
}

/** 注册对端连接状态变化回调 */
export function onSessionStatusChange(callback: (status: string) => void): void {
  _statusCallback = callback;
}

/** 注册远端数据变更回调（副设备监听 dataObj 变更） */
export function onRemoteDataChange(dataObj: object, callback: (dataObj: object) => void): void {
  _changeCallback = callback;
}

/**
 * 清理分布式 Session，解除事件监听
 * 在页面 aboutToDisappear 中调用
 */
export function cleanupDistributedSession(dataObj: object | null): void {
  hilog.info(0x0000, 'AIInterviewer', 'dist: cleanupDistributedSession called');
  if (!dataObj) { return; }
  try {
    const dobj: Record<string, Object> = dataObj as Record<string, Object>;
    // 尝试释放 session 关联，避免再次创建时报 err 1652（same sessionId）
    try {
      (dobj['setSessionId'] as Function)('');
      hilog.info(0x0000, 'AIInterviewer', 'dist: session released via setSessionId empty');
    } catch (_e) {
      hilog.info(0x0000, 'AIInterviewer', 'dist: setSessionId empty not supported, relying on GC');
    }
    (dobj['off'] as Function)('status');
    (dobj['off'] as Function)('change');
  } catch (err) {
    const em: string = (err as Error).message;
    hilog.error(0x0000, 'AIInterviewer', 'cleanupDistributedSession: %{private}s', em);
  }
  _online = false;
  _statusCallback = null;
  _changeCallback = null;
}

/**
 * 增量更新分布式对象字段
 * @param dataObj - createDistributedSession 返回的句柄
 * @param key - 字段名（仅允许 SYNC_ALLOWED_KEYS）
 * @param value - 新值
 */
export function updateSyncField(dataObj: object | null, key: string, value: Object): void {
  if (!dataObj) { return; }
  if (SYNC_ALLOWED_KEYS.indexOf(key) < 0) { return; }
  try {
    (dataObj as Record<string, Object>)[key] = value;
  } catch (err) {
    const em: string = (err as Error).message;
  }
}

/**
 * 读取分布式对象字段
 * @param dataObj - createDistributedSession 返回的句柄
 * @param key - 字段名
 * @returns 字段值，失败返回 null
 */
export function getSyncField(dataObj: object | null, key: string): Object | null {
  if (!dataObj) { return null; }
  if (SYNC_ALLOWED_KEYS.indexOf(key) < 0) { return null; }
  try {
    return (dataObj as Record<string, Object>)[key];
  } catch (err) {
    const em: string = (err as Error).message;
    hilog.error(0x0000, 'AIInterviewer', 'getSyncField: %{private}s', em);
    return null;
  }
}
