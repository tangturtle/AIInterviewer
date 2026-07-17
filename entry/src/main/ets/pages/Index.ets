import router from '@ohos.router';
import { pasteboard } from '@kit.BasicServicesKit';
import { hasApiKey, saveApiKey } from '../utils/PreferencesManager';

@Entry
@Component
struct Index {
  @State jdText: string = '';
  @State showApiKeyDialog: boolean = false;
  @State apiKeyInput: string = '';
  @State hasKey: boolean = false;

  aboutToAppear(): void {
    this.checkApiKey();
  }

  private async checkApiKey(): Promise<void> {
    this.hasKey = await hasApiKey(getContext(this));
    if (!this.hasKey) {
      this.showApiKeyDialog = true;
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

  private async saveApiKeyFromDialog(): Promise<void> {
    if (!this.apiKeyInput.trim()) {
      return;
    }
    await saveApiKey(getContext(this), this.apiKeyInput.trim());
    this.hasKey = true;
    this.showApiKeyDialog = false;
    this.apiKeyInput = '';
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

      // API Key 状态提示
      Row() {
        Text(this.hasKey ? '✓ API Key 已配置' : '✗ 未配置 API Key')
          .fontSize(13)
          .fontColor(this.hasKey ? '#34C759' : '#FF9500');
        Text('修改')
          .fontSize(13)
          .fontColor('#0A59F7')
          .margin({ left: 8 })
          .onClick(() => {
            this.showApiKeyDialog = true;
          });
      }
      .margin({ top: 24 });
    }
    .padding({ left: 20, right: 20 })
    .height('100%')
    .width('100%')
    .backgroundColor(Color.White)

    // API Key 配置弹窗
    .bindContentCover(this.showApiKeyDialog, this.ApiKeyDialogBuilder())
  }

  @Builder
  ApiKeyDialogBuilder(): void {
    Column() {
      Text($r('app.string.index_api_key_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 });

      TextInput({
        placeholder: $r('app.string.index_api_key_placeholder'),
        text: this.apiKeyInput
      })
        .type(InputType.Password)
        .height(44)
        .borderRadius(8)
        .borderColor('#E0E0E0')
        .borderWidth(1)
        .padding({ left: 12 })
        .onChange((value: string) => {
          this.apiKeyInput = value;
        });

      Row() {
        Button('取消')
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .height(40)
          .onClick(() => {
            this.showApiKeyDialog = false;
          });

        Button($r('app.string.index_api_key_save'))
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .borderRadius(8)
          .height(40)
          .onClick(() => this.saveApiKeyFromDialog());
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 20 });
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .width('85%')
  }
}
