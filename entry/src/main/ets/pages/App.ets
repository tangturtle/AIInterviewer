/**
 * Navigation 路由主机页面
 *
 * 使用 Navigation + NavPathStack 替代已废弃的 @ohos.router。
 * 所有子页面通过 .navDestination() 注册。
 */
import { IndexPage } from './Index';
import { InterviewPage } from './Interview';
import { ReportPage } from './Report';
import { SettingPage } from './Setting';

type NavPageParam = Record<string, Object>;

@Entry
@Component
struct App {
  private navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // 初始加载后无页面入栈，Navigation 自动显示默认内容（即 IndexPage）
  }

  build() {
    Navigation(this.navStack) {
      // 默认首页（NavPathStack 为空时显示）
      IndexPage({ navStack: this.navStack })
    }
    .hideTitleBar(true)
    .navDestination(this.NavDestinationBuilder)
    .backgroundColor($r('app.color.page_background'));
  }

  @Builder
  NavDestinationBuilder(name: string, param: Object) {
    if (name === 'Interview') {
      InterviewPage({ navStack: this.navStack, params: param as NavPageParam })
    } else if (name === 'Report') {
      ReportPage({ navStack: this.navStack, params: param as NavPageParam })
    } else if (name === 'Setting') {
      SettingPage({ navStack: this.navStack })
    }
  }
}
