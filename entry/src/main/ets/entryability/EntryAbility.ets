import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { hasApiKey } from '../utils/PreferencesManager';
import { http } from '@kit.NetworkKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'AIInterviewer', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onWindowStageCreate');

    // 先检查 API Key 来决定初始页面
    const initPage = this.determineStartPage();
    windowStage.loadContent(initPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AIInterviewer', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'Loaded initial page: %{public}s', initPage);
    });
  }

  /**
   * 判断启动页面：无 API Key 则跳配置页，否则跳首页
   */
  private determineStartPage(): string {
    // 同步检查是否有 Key（通过同步方式读取缓存）
    // 实际异步检查在 Index.ets 的 aboutToAppear 中处理
    return 'pages/Index';
  }

  private async checkNetworkAndKey(): Promise<void> {
    try {
      // 网络连通性检测
      const req = http.createHttp();
      let networkOk = false;
      try {
        const resp = await req.request('https://www.baidu.com', {
          method: http.RequestMethod.HEAD,
          connectTimeout: 5000,
          readTimeout: 5000
        });
        networkOk = resp.responseCode >= 200 && resp.responseCode < 500;
      } catch (err) {
        networkOk = false;
      } finally {
        req.destroy();
      }

      if (!networkOk) {
        hilog.warn(DOMAIN, 'AIInterviewer', 'Network check failed — 网络不可用');
        // 网络检测失败只记日志，不阻塞启动
      } else {
        hilog.info(DOMAIN, 'AIInterviewer', 'Network check passed');
      }
    } catch (err) {
      hilog.error(DOMAIN, 'AIInterviewer', 'checkNetwork failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onBackground');
  }
}
