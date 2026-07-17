import router from '@ohos.router';
import { getApiKey, saveApiKey, saveProvider, getProvider, BUILTIN_ENDPOINTS, DEFAULT_PROVIDER } from '../utils/PreferencesManager';
import { testConnection } from '../utils/http';

@Entry
@Component
struct Setting {
  @State providerIndex: number = 0;
  @State apiKeyInput: string = '';
  @State testResult: string = '';
  @State testColor: string = '#999999';
  @State isTesting: boolean = false;

  private providerOptions: SelectOption[] = [
    { value: 'DeepSeek' },
    { value: 'OpenAI' }
  ];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const key = await getApiKey(getContext(this));
    if (key) {
      this.apiKeyInput = key;
    }
    const provider = await getProvider(getContext(this));
    if (provider === 'openai') {
      this.providerIndex = 1;
    } else {
      this.providerIndex = 0;
    }
  }

  private getProviderName(index: number): string {
    return index === 0 ? 'deepseek' : 'openai';
  }

  private async handleTestConnection(): Promise<void> {
    if (!this.apiKeyInput.trim()) {
      this.testResult = '请先输入 API Key';
      this.testColor = '#FF3B30';
      return;
    }
    this.isTesting = true;
    this.testResult = '检测中...';
    this.testColor = '#999999';

    const provider = this.getProviderName(this.providerIndex);
    const endpoint = BUILTIN_ENDPOINTS[provider];

    const ok = await testConnection(this.apiKeyInput.trim(), endpoint);
    this.isTesting = false;

    if (ok) {
      this.testResult = '连接成功！API Key 有效';
      this.testColor = '#34C759';
    } else {
      this.testResult = '连接失败，请检查网络和 API Key';
      this.testColor = '#FF3B30';
    }
  }

  private async handleConfirm(): Promise<void> {
    if (!this.apiKeyInput.trim()) {
      return;
    }
    const provider = this.getProviderName(this.providerIndex);
    await saveProvider(getContext(this), provider);
    await saveApiKey(getContext(this), this.apiKeyInput.trim());
    router.replaceUrl({ url: 'pages/Index' });
  }

  private handleCancel(): void {
    router.replaceUrl({ url: 'pages/Index' });
  }

  build() {
    Column() {
      // 标题
      Text('API 配置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .margin({ top: 40, bottom: 32 });

      // 接口供应商选择
      Text('接口供应商')
        .fontSize(15)
        .fontColor('#666666')
        .width('100%')
        .margin({ bottom: 8 });

      Row() {
        Select(this.providerOptions)
          .selected(this.providerIndex)
          .value(this.providerOptions[this.providerIndex].value)
          .font({ size: 16 })
          .height(48)
          .width('100%')
          .onSelect((index: number, value: string) => {
            this.providerIndex = index;
            this.testResult = '';
          });
      }
      .padding({ left: 12, right: 12 })
      .backgroundColor('#F8F9FA')
      .borderRadius(8)
      .width('100%')
      .margin({ bottom: 20 });

      // API Key 输入
      Text('API Key')
        .fontSize(15)
        .fontColor('#666666')
        .width('100%')
        .margin({ bottom: 8 });

      TextInput({
        placeholder: '请输入您的 API Key',
        text: this.apiKeyInput
      })
        .type(InputType.Password)
        .height(48)
        .borderRadius(8)
        .borderColor('#E0E0E0')
        .borderWidth(1)
        .padding({ left: 12 })
        .width('100%')
        .onChange((value: string) => {
          this.apiKeyInput = value;
          this.testResult = '';
        });

      // 连通性测试结果
      if (this.testResult.length > 0) {
        Text(this.testResult)
          .fontSize(14)
          .fontColor(this.testColor)
          .width('100%')
          .margin({ top: 8 });
      }

      // 按钮区域
      Column() {
        // 检测连通性
        Button('检测连通性')
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .height(44)
          .width('100%')
          .enabled(!this.isTesting && this.apiKeyInput.trim().length > 0)
          .opacity(!this.isTesting && this.apiKeyInput.trim().length > 0 ? 1 : 0.5)
          .onClick(() => this.handleTestConnection());

        // 确认 + 取消
        Row() {
          Button('取消')
            .backgroundColor('#F0F0F0')
            .fontColor('#333333')
            .borderRadius(8)
            .height(44)
            .layoutWeight(1)
            .margin({ right: 8 })
            .onClick(() => this.handleCancel());

          Button('确认')
            .backgroundColor('#0A59F7')
            .fontColor(Color.White)
            .borderRadius(8)
            .height(44)
            .layoutWeight(1)
            .margin({ left: 8 })
            .enabled(this.apiKeyInput.trim().length > 0)
            .opacity(this.apiKeyInput.trim().length > 0 ? 1 : 0.5)
            .onClick(() => this.handleConfirm());
        }
        .width('100%')
        .margin({ top: 16 });
      }
      .width('100%')
      .margin({ top: 32 });
    }
    .padding({ left: 24, right: 24 })
    .height('100%')
    .width('100%')
    .backgroundColor(Color.White);
  }
}
