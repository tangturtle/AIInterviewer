import router from '@ohos.router';
import { pasteboard } from '@kit.BasicServicesKit';
import { hasApiKey } from '../utils/PreferencesManager';

@Entry
@Component
struct Index {
  @State jdText: string = '';
  @State hasKey: boolean = false;

  aboutToAppear(): void {
    this.checkApiKey();
  }

  private async checkApiKey(): Promise<void> {
    this.hasKey = await hasApiKey(getContext(this));
    if (!this.hasKey) {
      // 无 API Key，跳转配置页面
      router.replaceUrl({ url: 'pages/Setting' });
    }
  }

  private async pasteFromClipboard(): Promise<void> {
    try {
      const pasteData = await pasteboard.getSystemPasteboard().getData();
      if (pasteData) {
        const record = pasteData.getRecord(0);
        const text = await record.convertToText();
        if (text) {
          this.jdText = text;
        }
      }
    } catch (err) {
      // 剪贴板读取失败，静默处理
    }
  }

  private startInterview(): void {
    if (!this.jdText.trim()) {
      return;
    }
    router.pushUrl({
      url: 'pages/Interview',
      params: {
        jdText: this.jdText
      }
    });
  }

  private goToSetting(): void {
    router.pushUrl({ url: 'pages/Setting' });
  }

  build() {
    Column() {
      // 顶部标题区
      Column() {
        Text($r('app.string.index_title'))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0A59F7');
        Text($r('app.string.index_subtitle'))
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 });
      }
      .margin({ top: 40, bottom: 24 });

      // JD 输入区
      TextArea({
        text: this.jdText,
        placeholder: $r('app.string.index_jd_placeholder')
      })
        .height(220)
        .borderRadius(12)
        .borderColor('#E0E0E0')
        .borderWidth(1)
        .padding(12)
        .fontSize(15)
        .onChange((value: string) => {
          this.jdText = value;
        });

      // 功能按钮行
      Row() {
        Button($r('app.string.index_paste_button'))
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .height(40)
          .onClick(() => this.pasteFromClipboard());

        Button($r('app.string.index_start_button'))
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .borderRadius(8)
          .height(40)
          .width(120)
          .enabled(this.jdText.trim().length > 0)
          .opacity(this.jdText.trim().length > 0 ? 1 : 0.5)
          .onClick(() => this.startInterview());
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 16 });

      // API Key 状态 + 配置入口
      Row() {
        Text(this.hasKey ? '✓ API Key 已配置' : '✗ 未配置 API Key')
          .fontSize(13)
          .fontColor(this.hasKey ? '#34C759' : '#FF9500');
        Text('设置')
          .fontSize(13)
          .fontColor('#0A59F7')
          .margin({ left: 8 })
          .onClick(() => this.goToSetting());
      }
      .margin({ top: 24 });
    }
    .padding({ left: 20, right: 20 })
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'));
  }
}
