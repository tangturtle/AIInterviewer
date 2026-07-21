import { getApiKey, saveApiKey, saveProvider, getProvider, saveModel, getModel, saveTestCache, getTestCache, clearTestCache, BUILTIN_ENDPOINTS, DEFAULT_PROVIDER, DEFAULT_MODELS, TestCache } from '../utils/PreferencesManager';
import { testConnection, fetchModels, fetchBalance } from '../utils/http';
import { getDistributedEnabled, saveDistributedEnabled, createDistributedSession, cleanupDistributedSession, onSessionStatusChange, getSessionOnline } from '../utils/DistributedSync';

@Component
export struct SettingPage {
  navStack: NavPathStack = new NavPathStack();

  @State providerIndex: number = 0;
  @State apiKeyInput: string = '';
  @State testResult: string = '';
  @State isTesting: boolean = false;
  @State balanceInfo: string = '';
  @State modelOptions: SelectOption[] = [];
  @State modelIndex: number = 0;
  @State selectedModel: string = '';
  @State savedFeedback: boolean = false;
  @State isApiFocused: boolean = false;
  @State distributedEnabled: boolean = false;
  @State distributedOnline: boolean = false;
  @State distributedChecking: boolean = false;
  private isLoadingKey: boolean = false;
  private loadedApiKey: string = '';
  private distributedSession: object | null = null;

  private providerOptions: SelectOption[] = [
    { value: 'DeepSeek' },
    { value: 'OpenAI' }
  ];

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    this.isLoadingKey = true;
    try {
      const ctx = getContext(this);
      const key = await getApiKey(ctx);
      this.loadedApiKey = key || '';
      if (key) { this.apiKeyInput = key; }
      const provider = await getProvider(ctx);
      this.providerIndex = provider === 'openai' ? 1 : 0;
      const savedModel = await getModel(ctx);
      if (savedModel) { this.selectedModel = savedModel; }

      // 恢复测试缓存，避免每次都需要重新检测连通性
      const cache = await getTestCache(ctx);
      const currentProvider = this.getProviderName(this.providerIndex);
      if (cache && cache.provider === currentProvider && cache.models.length > 0) {
        this.testResult = cache.testResult;
        this.balanceInfo = cache.balance;
        const opts: SelectOption[] = [];
        for (let i = 0; i < cache.models.length; i++) { opts.push({ value: cache.models[i] }); }
        this.modelOptions = opts;
        const idx = cache.models.indexOf(cache.selectedModel);
        if (idx >= 0) {
          this.modelIndex = idx;
          this.selectedModel = cache.models[idx];
        } else if (cache.models.length > 0) {
          this.modelIndex = 0;
          this.selectedModel = cache.models[0];
        }
      } else if (this.apiKeyInput) {
        // 有 Key 但无缓存/缓存不匹配，自动获取模型列表，无需手动点检测
        void this.fetchModelsSilent();
      }

      // 读取分布式开关状态
      this.distributedEnabled = await getDistributedEnabled(ctx);
    } finally {
      this.isLoadingKey = false;
    }
  }

  private async fetchModelsSilent(): Promise<void> {
    const provider = this.getProviderName(this.providerIndex);
    const endpoint = BUILTIN_ENDPOINTS[provider];
    const apiKey = this.apiKeyInput.trim();
    if (!apiKey) { return; }

    let models: string[] = [];
    try {
      models = await fetchModels(apiKey, endpoint);
    } catch (_e) {
      this.testResult = '✗ 网络异常，可点击检测连通性重试';
      this.modelOptions = this.selectedModel ? [{ value: this.selectedModel }] : [];
      return;
    }
    if (models.length > 0) {
      const opts: SelectOption[] = [];
      for (let i = 0; i < models.length; i++) { opts.push({ value: models[i] }); }
      this.modelOptions = opts;
      this.testResult = '连接成功，已获取 ' + models.length + ' 个模型';
      let foundIdx = 0;
      for (let i = 0; i < models.length; i++) {
        if (models[i] === this.selectedModel) { foundIdx = i; break; }
      }
      this.modelIndex = foundIdx;
      this.selectedModel = models[foundIdx];
    } else {
      const dm = DEFAULT_MODELS[provider] || 'deepseek-v4-flash';
      this.modelOptions = [{ value: dm }];
      this.modelIndex = 0;
      this.selectedModel = dm;
      this.testResult = '连接成功（无法获取模型列表，使用默认模型）';
    }
    let balanceInfo = '';
    if (provider === 'deepseek') {
      const balance = await fetchBalance(apiKey);
      if (balance) { balanceInfo = balance; this.balanceInfo = balance; }
    }
    const modelsArr: string[] = [];
    for (let i = 0; i < this.modelOptions.length; i++) { modelsArr.push('' + this.modelOptions[i].value); }
    await saveTestCache(getContext(this), {
      provider: provider,
      models: modelsArr,
      testResult: this.testResult,
      balance: balanceInfo,
      selectedModel: this.selectedModel
    });
  }

  aboutToDisappear(): void {
    cleanupDistributedSession(this.distributedSession);
    this.distributedSession = null;
  }

  private async toggleDistributed(checked: boolean): Promise<void> {
    const ctx = getContext(this);
    await saveDistributedEnabled(ctx, checked);
    this.distributedEnabled = checked;
    if (checked) {
      this.distributedChecking = true;
      this.distributedSession = await createDistributedSession(ctx);
      this.distributedChecking = false;
      if (this.distributedSession) {
        onSessionStatusChange((status: string): void => {
          this.distributedOnline = status === '已连接';
        });
      } else {
        this.distributedOnline = false;
      }
    } else {
      cleanupDistributedSession(this.distributedSession);
      this.distributedSession = null;
      this.distributedOnline = false;
    }
  }

  private getDistributedStatusText(): string {
    if (!this.distributedEnabled) { return '已禁用'; }
    if (this.distributedChecking) { return '检测中...'; }
    if (this.distributedOnline) { return '对端在线'; }
    return '未检测到对端设备';
  }

  private getDistributedStatusColor(): Resource {
    if (!this.distributedEnabled) { return $r('app.color.text_tip'); }
    if (this.distributedChecking) { return $r('app.color.text_secondary'); }
    if (this.distributedOnline) { return $r('app.color.text_success'); }
    return $r('app.color.text_warning');
  }

  private getDistributedStatusIcon(): string {
    if (!this.distributedEnabled) { return '⚪'; }
    if (this.distributedChecking) { return '🔄'; }
    if (this.distributedOnline) { return '🟢'; }
    return '🔴';
  }

  private getProviderName(index: number): string {
    return index === 0 ? 'deepseek' : 'openai';
  }

  private getProviderLabel(index: number): string {
    return index === 0 ? 'DeepSeek' : 'OpenAI';
  }

  private async handleTestConnection(): Promise<void> {
    if (!this.apiKeyInput.trim()) {
      this.testResult = '! 请先输入 API Key';
      return;
    }
    this.isTesting = true;
    this.testResult = '○ 检测中...';
    this.balanceInfo = '';
    this.modelOptions = [];

    const provider = this.getProviderName(this.providerIndex);
    const endpoint = BUILTIN_ENDPOINTS[provider];
    const defaultModel = DEFAULT_MODELS[provider] || 'deepseek-v4-flash';
    const apiKey = this.apiKeyInput.trim();

    const ok = await testConnection(apiKey, endpoint, defaultModel);
    this.isTesting = false;

    if (ok) {
      this.testResult = '✓ 连接成功！正在获取模型列表...';
      const models = await fetchModels(apiKey, endpoint);
      if (models.length > 0) {
        const opts: SelectOption[] = [];
        for (let i = 0; i < models.length; i++) { opts.push({ value: models[i] }); }
        this.modelOptions = opts;
        this.testResult = '连接成功，已获取 ' + models.length + ' 个模型';
        let foundIdx = 0;
        for (let i = 0; i < models.length; i++) {
          if (models[i] === this.selectedModel) { foundIdx = i; break; }
        }
        this.modelIndex = foundIdx;
        this.selectedModel = models[foundIdx];
      } else {
        const dm = DEFAULT_MODELS[provider] || 'deepseek-v4-flash';
        this.modelOptions = [{ value: dm }];
        this.modelIndex = 0;
        this.selectedModel = dm;
        this.testResult = '连接成功（无法获取模型列表，使用默认模型）';
      }
      if (provider === 'deepseek') {
        const balance = await fetchBalance(apiKey);
        if (balance) { this.balanceInfo = balance; }
      }
      // 保存测试缓存
      const modelsArr: string[] = [];
      for (let i = 0; i < this.modelOptions.length; i++) { modelsArr.push('' + this.modelOptions[i].value); }
      await saveTestCache(getContext(this), {
        provider: provider,
        models: modelsArr,
        testResult: this.testResult,
        balance: this.balanceInfo,
        selectedModel: this.selectedModel
      });
    } else {
      this.testResult = '✗ 连接失败，请检查网络和 API Key';
    }
  }

  private async handleConfirm(): Promise<void> {
    if (!this.apiKeyInput.trim()) { return; }
    const ctx = getContext(this);
    const provider = this.getProviderName(this.providerIndex);
    await saveProvider(ctx, provider);
    await saveApiKey(ctx, this.apiKeyInput.trim());
    if (this.selectedModel) { await saveModel(ctx, this.selectedModel); }
    this.savedFeedback = true;
    setTimeout((): void => {
      this.navStack.pop();
    }, 800);
  }

  private handleCancel(): void {
    this.navStack.pop();
  }

  private getResultIcon(): string {
    if (this.testResult.startsWith('✓')) return '✓';
    if (this.testResult.startsWith('✗') || this.testResult.startsWith('!')) return '✗';
    return '○';
  }

  private getResultBg(): Resource {
    if (this.testResult.startsWith('✓')) return $r('app.color.success_bg');
    if (this.testResult.startsWith('✗') || this.testResult.startsWith('!')) return $r('app.color.error_bg');
    return $r('app.color.card_background_light');
  }

  private getResultColor(): Resource {
    if (this.testResult.startsWith('✓')) return $r('app.color.text_success');
    if (this.testResult.startsWith('✗') || this.testResult.startsWith('!')) return $r('app.color.text_danger');
    return $r('app.color.text_secondary');
  }

  build() {
    NavDestination() {
      Scroll() {
        Column() {
          // ── 页面标题 ────────────────────────────────
          Column() {
            Text('API 配置')
              .fontSize(24).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'));
            Text('设置接口供应商和模型参数')
              .fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 4 });
          }
          .width('100%').alignItems(HorizontalAlign.Start).margin({ top: 32, bottom: 24 });

          // ═══ 供应商卡片 ══════════════════════════════
          Column() {
            Row() {
              Text('🔌').fontSize(18).margin({ right: 12 });
              Column() {
                Text('接口供应商').fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'));
                Text(this.getProviderLabel(this.providerIndex) === 'DeepSeek'
                  ? '国内可直连，支持 JSON mode' : '海外标杆，需代理/VPN')
                  .fontSize(12).fontColor($r('app.color.text_tip')).margin({ top: 2 });
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1);
            }
            .width('100%').margin({ bottom: 12 });

            Row() {
              Select(this.providerOptions)
                .selected(this.providerIndex).value(this.providerOptions[this.providerIndex].value)
                .font({ size: 16 }).height(48).width('100%')
                .optionWidth(OptionWidthMode.FIT_TRIGGER)
                .fontColor($r('app.color.text_primary'))
                .optionFont({ size: 15 })
                .optionFontColor($r('app.color.text_primary'))
                .optionBgColor($r('app.color.card_background'))
                .selectedOptionFont({ size: 15, weight: FontWeight.Medium })
                .selectedOptionFontColor($r('app.color.primary'))
                .selectedOptionBgColor($r('app.color.primary_light'))
                .menuBackgroundColor($r('app.color.card_background'))
                .onSelect((index: number) => {
                  this.providerIndex = index;
                  this.testResult = '';
                  this.modelOptions = [];
                  this.modelIndex = 0;
                  this.selectedModel = '';
                  this.balanceInfo = '';
                  clearTestCache(getContext(this));
                })
                .accessibilityText('选择接口供应商');
            }
            .width('100%');
          }
          .padding(16).backgroundColor($r('app.color.card_background')).borderRadius(14)
          .width('100%').margin({ bottom: 16 })
          .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });

          // ═══ API Key 卡片 ════════════════════════════
          Column() {
            Row() {
              Text('🔑').fontSize(18).margin({ right: 12 });
              Column() {
                Text('API Key').fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'));
                Text('密钥仅保存在本地，不会上传云端')
                  .fontSize(12).fontColor($r('app.color.text_tip')).margin({ top: 2 });
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1);
            }
            .width('100%').margin({ bottom: 12 });

            Row() {
              TextInput({ placeholder: '请输入您的 API Key', text: this.apiKeyInput })
                .type(InputType.Password).height(48).borderRadius(10)
                .borderColor(this.isApiFocused ? $r('app.color.input_focus_border') : $r('app.color.border'))
                .borderWidth(this.isApiFocused ? 1.5 : 1).padding({ left: 14 }).width('100%')
                .fontColor($r('app.color.text_primary')).backgroundColor($r('app.color.input_background'))
                .onChange((value: string) => {
                  this.apiKeyInput = value;
                  if (value === this.loadedApiKey) { return; }
                  this.testResult = '';
                  this.modelOptions = [];
                  clearTestCache(getContext(this));
                })
                .onFocus((): void => { this.isApiFocused = true; })
                .onBlur((): void => { this.isApiFocused = false; })
                .accessibilityText('输入 API Key')
                .layoutWeight(1);
            }
            .width('100%');

            if (this.savedFeedback) {
              Text('✓ 已保存，即将返回')
                .fontSize(13).fontColor($r('app.color.text_success'))
                .width('100%').margin({ top: 8 });
            }
          }
          .padding(16).backgroundColor($r('app.color.card_background')).borderRadius(14)
          .width('100%').margin({ bottom: 16 })
          .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });

          // ═══ 测试结果区 ════════════════════════════
          if (this.testResult.length > 0) {
            Column() {
              Row() {
                Text(this.getResultIcon()).fontSize(20)
                  .fontColor(this.getResultColor()).margin({ right: 10 });
                Column() {
                  Text(this.testResult).fontSize(14)
                    .fontColor(this.getResultColor());
                  if (this.balanceInfo.length > 0) {
                    Divider().height(1).color($r('app.color.border')).margin({ top: 8, bottom: 8 });
                    Row() {
                      Text('💰').fontSize(14).margin({ right: 6 });
                      Text('余额').fontSize(13).fontColor($r('app.color.text_primary'));
                      Text(this.balanceInfo).fontSize(13)
                        .fontColor($r('app.color.text_success')).margin({ left: 'auto' });
                    }
                    .width('100%');
                  }
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1);
              }
              .width('100%');
            }
            .padding(14).backgroundColor(this.getResultBg())
            .borderRadius(10).width('100%').margin({ bottom: 16 });
          }

          // ═══ 模型选择卡片 ══════════════════════════
          if (this.modelOptions.length > 0) {
            Column() {
              Row() {
                Text('🧠').fontSize(18).margin({ right: 12 });
                Column() {
                  Text('选择模型').fontSize(15).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'));
                  Text('当前: ' + this.modelOptions[this.modelIndex].value)
                    .fontSize(12).fontColor($r('app.color.text_tip')).margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1);
              }
              .width('100%').margin({ bottom: 12 });

              Row() {
                Select(this.modelOptions)
                  .selected(this.modelIndex).value(this.modelOptions[this.modelIndex].value)
                  .font({ size: 16 }).height(48).width('100%')
                  .optionWidth(OptionWidthMode.FIT_TRIGGER)
                  .optionHeight(320)
                  .fontColor($r('app.color.text_primary'))
                  .optionFont({ size: 15 })
                  .optionFontColor($r('app.color.text_primary'))
                  .optionBgColor($r('app.color.card_background'))
                  .selectedOptionFont({ size: 15, weight: FontWeight.Medium })
                  .selectedOptionFontColor($r('app.color.primary'))
                  .selectedOptionBgColor($r('app.color.primary_light'))
                  .menuBackgroundColor($r('app.color.card_background'))
                  .onSelect((index: number, value: string) => {
                    this.modelIndex = index;
                    this.selectedModel = value;
                  })
                  .accessibilityText('选择模型');
              }
              .width('100%');
            }
            .padding(16).backgroundColor($r('app.color.card_background')).borderRadius(14)
            .width('100%').margin({ bottom: 16 })
            .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });
          }

          // ═══ 分布式同步卡片 ═════════════════════════
          Column() {
            Row() {
              Text('📡').fontSize(18).margin({ right: 12 });
              Column() {
                Text('分布式同步').fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'));
                Text('在手机和平板间同步面试进度')
                  .fontSize(12).fontColor($r('app.color.text_tip')).margin({ top: 2 });
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1);
              Toggle({ type: ToggleType.Switch, isOn: this.distributedEnabled })
                .onChange((isOn: boolean): void => { void this.toggleDistributed(isOn); });
            }
            .width('100%').margin({ bottom: 12 });

            Row() {
              Text(this.getDistributedStatusIcon()).fontSize(16).margin({ right: 8 });
              Text(this.getDistributedStatusText()).fontSize(13)
                .fontColor(this.getDistributedStatusColor());
            }
            .width('100%');

            if (this.distributedEnabled) {
              Text('请在两台设备安装此应用并登录同一华为账号')
                .fontSize(11).fontColor($r('app.color.text_tip')).width('100%').margin({ top: 8 });
            }
          }
          .padding(16).backgroundColor($r('app.color.card_background')).borderRadius(14)
          .width('100%').margin({ bottom: 16 })
          .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });

          // ═══ 操作按钮区 ═══════════════════════════
          Button('检测连通性')
            .backgroundColor($r('app.color.card_background'))
            .fontColor($r('app.color.primary'))
            .fontSize(15).borderRadius(10).height(48).width('100%')
            .borderColor($r('app.color.primary')).borderWidth(1)
            .enabled(!this.isTesting && this.apiKeyInput.trim().length > 0)
            .opacity(!this.isTesting && this.apiKeyInput.trim().length > 0 ? 1 : 0.5)
            .onClick(() => this.handleTestConnection()).accessibilityText('测试 API 连通性');

          Row() {
            Button('取消')
              .backgroundColor($r('app.color.step_inactive')).fontColor($r('app.color.text_primary'))
              .fontSize(15).borderRadius(10).height(48).layoutWeight(1).margin({ right: 8 })
              .onClick(() => this.handleCancel()).accessibilityText('取消并返回首页');

            Button('保存配置')
              .backgroundColor($r('app.color.primary')).fontColor($r('app.color.white'))
              .fontSize(15).borderRadius(10).height(48).layoutWeight(1).margin({ left: 8 })
              .enabled(this.apiKeyInput.trim().length > 0)
              .opacity(this.apiKeyInput.trim().length > 0 ? 1 : 0.45)
              .onClick(() => this.handleConfirm()).accessibilityText('保存配置');
          }
          .width('100%').margin({ top: 16, bottom: 32 });
        }
        .padding({ left: 24, right: 24 }).width('100%');
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor($r('app.color.page_background'))
    .hideTitleBar(true);
  }
}
