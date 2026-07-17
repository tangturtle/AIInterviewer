import router from '@ohos.router';
import { getApiKey, saveApiKey, saveProvider, getProvider, saveModel, getModel, BUILTIN_ENDPOINTS, DEFAULT_PROVIDER, DEFAULT_MODELS } from '../utils/PreferencesManager';
import { testConnection, fetchModels, fetchBalance } from '../utils/http';

@Entry
@Component
struct Setting {
  @State providerIndex: number = 0;
  @State apiKeyInput: string = '';
  @State testResult: string = '';
  @State testColor: string = '#999999';
  @State isTesting: boolean = false;
  @State balanceInfo: string = '';
  @State modelOptions: SelectOption[] = [];
  @State modelIndex: number = 0;
  @State selectedModel: string = '';

  private providerOptions: SelectOption[] = [
    { value: 'DeepSeek' },
    { value: 'OpenAI' }
  ];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    const ctx = getContext(this);
    const key = await getApiKey(ctx);
    if (key) {
      this.apiKeyInput = key;
    }
    const provider = await getProvider(ctx);
    if (provider === 'openai') {
      this.providerIndex = 1;
    } else {
      this.providerIndex = 0;
    }
    const savedModel = await getModel(ctx);
    if (savedModel) {
      this.selectedModel = savedModel;
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
    this.balanceInfo = '';
    this.modelOptions = [];

    const provider = this.getProviderName(this.providerIndex);
    const endpoint = BUILTIN_ENDPOINTS[provider];
    const apiKey = this.apiKeyInput.trim();

    const ok = await testConnection(apiKey, endpoint);
    this.isTesting = false;

    if (ok) {
      this.testResult = '连接成功！正在获取模型列表...';
      this.testColor = '#34C759';

      // 获取可用模型
      const models = await fetchModels(apiKey, endpoint);
      if (models.length > 0) {
        const opts: SelectOption[] = [];
        for (let i = 0; i < models.length; i++) {
          opts.push({ value: models[i] });
        }
        this.modelOptions = opts;
        this.testResult = '连接成功，已获取 ' + models.length + ' 个模型';

        // 尝试匹配已保存的模型
        let foundIdx = 0;
        for (let i = 0; i < models.length; i++) {
          if (models[i] === this.selectedModel) {
            foundIdx = i;
            break;
          }
        }
        this.modelIndex = foundIdx;
        this.selectedModel = models[foundIdx];
      } else {
        // 获取失败，使用默认模型
        const defaultModel = DEFAULT_MODELS[provider] || 'deepseek-chat';
        this.modelOptions = [{ value: defaultModel }];
        this.modelIndex = 0;
        this.selectedModel = defaultModel;
        this.testResult = '连接成功（无法获取模型列表，使用默认模型）';
      }

      // 查询余额（仅 DeepSeek）
      if (provider === 'deepseek') {
        const balance = await fetchBalance(apiKey);
        if (balance) {
          this.balanceInfo = balance;
        }
      }
    } else {
      this.testResult = '连接失败，请检查网络和 API Key';
      this.testColor = '#FF3B30';
    }
  }

  private handleConfirm(): void {
    if (!this.apiKeyInput.trim()) {
      return;
    }
    const ctx = getContext(this);
    const provider = this.getProviderName(this.providerIndex);
    saveProvider(ctx, provider);
    saveApiKey(ctx, this.apiKeyInput.trim());
    if (this.selectedModel) {
      saveModel(ctx, this.selectedModel);
    }
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
            this.modelOptions = [];
            this.modelIndex = 0;
            this.selectedModel = '';
            this.balanceInfo = '';
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
          this.modelOptions = [];
        });

      // 连通性测试结果
      if (this.testResult.length > 0) {
        Text(this.testResult)
          .fontSize(14)
          .fontColor(this.testColor)
          .width('100%')
          .margin({ top: 8 });
      }

      // 余额信息
      if (this.balanceInfo.length > 0) {
        Text(this.balanceInfo)
          .fontSize(13)
          .fontColor('#666666')
          .width('100%')
          .margin({ top: 4 });
      }

      // 模型选择（连接成功后显示）
      if (this.modelOptions.length > 0) {
        Text('选择模型')
          .fontSize(15)
          .fontColor('#666666')
          .width('100%')
          .margin({ top: 16, bottom: 8 });

        Row() {
          Select(this.modelOptions)
            .selected(this.modelIndex)
            .value(this.modelOptions[this.modelIndex].value)
            .font({ size: 16 })
            .height(48)
            .width('100%')
            .onSelect((index: number, value: string) => {
              this.modelIndex = index;
              this.selectedModel = value;
            });
        }
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F8F9FA')
        .borderRadius(8)
        .width('100%')
        .margin({ bottom: 20 });
      }

      // 按钮区域
      Column() {
        Button('检测连通性')
          .backgroundColor('#F0F0F0')
          .fontColor('#333333')
          .borderRadius(8)
          .height(44)
          .width('100%')
          .enabled(!this.isTesting && this.apiKeyInput.trim().length > 0)
          .opacity(!this.isTesting && this.apiKeyInput.trim().length > 0 ? 1 : 0.5)
          .onClick(() => this.handleTestConnection());

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
      .margin({ top: 24 });
    }
    .padding({ left: 24, right: 24 })
    .height('100%')
    .width('100%')
    .backgroundColor(Color.White);
  }
}
