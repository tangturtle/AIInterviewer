import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

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

    // 先加载内容，再配置全屏和系统栏（必须在 loadContent 回调内执行）
    const initPage = this.determineStartPage();
    windowStage.loadContent(initPage, (err) => {
      if (err && err.code) {
        hilog.error(DOMAIN, 'AIInterviewer', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'Loaded initial page: %{public}s', initPage);

      // 内容加载完成后配置全屏
      windowStage.getMainWindow((winErr, win) => {
        if (winErr) {
          hilog.error(DOMAIN, 'AIInterviewer', 'getMainWindow failed: %{public}s', JSON.stringify(winErr));
          return;
        }
        if (win) {
          try {
            // 读取系统颜色模式，选择对应的颜色方案
            const colorMode = this.context.config?.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
            const isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
            const bgColor = isDark ? '#1A1A2E' : '#FFFFFF';
            const contentColor = isDark ? '#ffffff' : '#000000';

            // 设置窗口背景色与系统栏颜色一致（融为一体，无黑色边框）
            win.setWindowBackgroundColor(bgColor);
            // 全屏：内容延伸至整个屏幕
            win.setWindowLayoutFullScreen(true);
            // 隐藏系统状态栏和导航栏 UI 元素
            win.setWindowSystemBarEnable([]);
            // 系统栏底色与页面背景色相同，而非透明（透明叠加系统黑色面板 = 黑边）
            win.setWindowSystemBarProperties({
              statusBarColor: bgColor,
              navigationBarColor: bgColor,
              statusBarContentColor: contentColor,
              navigationBarContentColor: contentColor
            });
            hilog.info(DOMAIN, 'AIInterviewer', 'Fullscreen enabled, isDark=%{public}s', isDark ? 'true' : 'false');
          } catch (fsErr) {
            hilog.error(DOMAIN, 'AIInterviewer', 'Failed to set fullscreen: %{public}s', JSON.stringify(fsErr));
          }
        }
      });
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
