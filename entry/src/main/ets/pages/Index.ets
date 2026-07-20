import { pasteboard } from '@kit.BasicServicesKit';
import { hasApiKey, getProvider, getApiKey, getModel, saveModel, getTestCache, BUILTIN_ENDPOINTS, DEFAULT_MODELS } from '../utils/PreferencesManager';
import { fetchModels, fetchBalance } from '../utils/http';

@Component
export struct IndexPage {
  navStack: NavPathStack = new NavPathStack();
  @State jdText: string = '';
  @State hasKey: boolean = false;
  @State isFocused: boolean = false;
  @State selectedModel: string = '';
  @State modelOptions: SelectOption[] = [];
  @State modelIndex: number = 0;
  @State balanceInfo: string = '';
  @State isExpanded: boolean = false;
  @State connectionStatus: string = '';
  @State statusType: string = ''; // 'success' | 'warning'
  @State private redirectedToSetting: boolean = false;

  aboutToAppear(): void {
    this.checkApiKey();
  }

  private async checkApiKey(): Promise<void> {
    this.hasKey = await hasApiKey(getContext(this));
    if (!this.hasKey && !this.redirectedToSetting) {
      this.redirectedToSetting = true;
      const settingPath: NavPathInfo = { name: 'Setting' };
      this.navStack.replacePath(settingPath);
      return;
    }
    this.selectedModel = await getModel(getContext(this));
    const cache = await getTestCache(getContext(this));
    if (cache && cache.models.length > 0) {
      this.modelOptions = this.buildModelOptions(cache.models);
      this.updateModelSelection(cache.models);
      if (cache.balance) { this.balanceInfo = cache.balance; }
      this.connectionStatus = '';
      this.statusType = 'success';
    } else if (this.selectedModel) {
      this.connectionStatus = '';
      this.statusType = 'success';
      // 自动从后端拉取完整模型列表
      void this.tryFetchModels().catch(() => {});
    } else {
      this.connectionStatus = '请先在设置中配置 API';
      this.statusType = 'warning';
    }
  }

  private async pasteFromClipboard(): Promise<void> {
    try {
      const pasteData = await pasteboard.getSystemPasteboard().getData();
      if (pasteData) {
        try {
          const text: string = pasteData.getPrimaryText();
          if (text) {
            this.jdText = text;
            return;
          }
        } catch (err) {
          // getText() 不可用，跳过
        }
      }
    } catch (err) {
      // 剪贴板读取失败，静默处理
    }
  }

  private clearText(): void {
    this.jdText = '';
  }

  private startInterview(): void {
    if (!this.jdText.trim()) {
      return;
    }
    const jdParam: Record<string, Object> = { 'jdText': this.jdText };
    const pathInfo: NavPathInfo = { name: 'Interview', param: jdParam };
    this.navStack.pushPath(pathInfo);
  }

  private goToSetting(): void {
    const settingPath: NavPathInfo = { name: 'Setting' };
    this.navStack.pushPath(settingPath);
  }

  private async onModelSelected(index: number, value: string): Promise<void> {
    this.modelIndex = index;
    this.selectedModel = value;
    await saveModel(getContext(this), value);
  }

  private buildModelOptions(models: string[]): SelectOption[] {
    const opts: SelectOption[] = [];
    for (let i = 0; i < models.length; i++) { opts.push({ value: models[i] }); }
    return opts;
  }

  private updateModelSelection(models: string[]): void {
    const idx = models.indexOf(this.selectedModel);
    if (idx >= 0) {
      this.modelIndex = idx;
    } else {
      this.modelIndex = 0;
      this.selectedModel = models[0];
    }
  }

  private async tryFetchModels(): Promise<void> {
    const ctx = getContext(this);
    const provider = await getProvider(ctx);
    const endpoint = BUILTIN_ENDPOINTS[provider] || BUILTIN_ENDPOINTS.deepseek;
    const cache = await getTestCache(ctx);
    if (cache && cache.models.length > 0) {
      this.modelOptions = this.buildModelOptions(cache.models);
      this.updateModelSelection(cache.models);
      return;
    }
    const key = await getApiKey(ctx);
    if (!key) { return; }
    const defaultModel = DEFAULT_MODELS[provider] || 'deepseek-v4-flash';
    const models = await fetchModels(key, endpoint);
    if (models.length > 0) {
      this.modelOptions = this.buildModelOptions(models);
      this.updateModelSelection(models);
    } else {
      this.modelOptions = [{ value: this.selectedModel }];
      this.modelIndex = 0;
    }
    // 独立获取余额（仅 DeepSeek）
    if (provider === 'deepseek') {
      const balance = await fetchBalance(key);
      if (balance) { this.balanceInfo = balance; }
    }
  }

  build() {
    Column() {
      // ── 品牌区 ─────────────────────────────────────
      Column() {
        Text('AI')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.white'))
          .width(56)
          .height(56)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.primary'))
          .borderRadius(14)
          .margin({ bottom: 16 });

        Text($r('app.string.index_title'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'));

        Text($r('app.string.index_subtitle'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 32, bottom: 28 });

      // ── 连接状态条 ────────────────────────────
      if (this.connectionStatus.length > 0) {
        Row() {
          Text(this.statusType === 'success' ? '✓' : '!')
            .fontSize(12)
            .fontColor(this.statusType === 'success'
              ? $r('app.color.text_success') : $r('app.color.text_warning'))
            .margin({ right: 6 });
          Text(this.connectionStatus)
            .fontSize(12)
            .fontColor(this.statusType === 'success'
              ? $r('app.color.text_success') : $r('app.color.text_warning'));
        }
        .padding({ top: 6, bottom: 6, left: 12, right: 12 })
        .backgroundColor(this.statusType === 'success'
          ? $r('app.color.success_bg') : $r('app.color.warning_bg'))
        .borderRadius(8)
        .width('100%')
        .margin({ bottom: 16 });
      }

      // ── JD 输入卡片 ─────────────────────────────────
      Column() {
        Row() {
          Text('职位描述')
            .fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'));
          Text('粘贴或输入岗位 JD')
            .fontSize(12).fontColor($r('app.color.text_tip'))
            .margin({ left: 8 });
        }
        .width('100%').margin({ bottom: 8 });

        Stack() {
          TextArea({
            text: this.jdText,
            placeholder: $r('app.string.index_jd_placeholder')
          })
            .height(200)
            .borderRadius(12)
            .borderColor(this.isFocused ? $r('app.color.input_focus_border') : $r('app.color.border'))
            .borderWidth(1.5)
            .padding(14)
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.input_background'))
            .onChange((value: string) => {
              this.jdText = value;
            })
            .onFocus((): void => {
              this.isFocused = true;
            })
            .onBlur((): void => {
              this.isFocused = false;
            })
            .accessibilityText('请输入职位描述文本')

          Text(this.jdText.length + ' 字')
            .fontSize(11).fontColor($r('app.color.text_tip'))
            .align(Alignment.TopEnd)
            .margin({ top: 8, right: 8 });
        }
        .align(Alignment.TopEnd)
        .width('100%')

        if (this.jdText.trim().length > 0) {
          Row() {
            Text('✕ 清空')
              .fontSize(13)
              .fontColor($r('app.color.text_tip'))
              .onClick(() => this.clearText());
          }
          .accessibilityText('清空输入内容')
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 6 });
        }
      }
      .width('100%');

      // ── 功能按钮行 ─────────────────────────────────
      Row() {
        Button() {
          Row() {
            Text('📋')
              .fontSize(16)
              .margin({ right: 6 });
            Column() {
              Text($r('app.string.index_paste_button'))
                .fontSize(14)
                .fontColor($r('app.color.text_primary'));
              Text('粘贴板').fontSize(10)
                .fontColor($r('app.color.text_tip'));
            }
            .alignItems(HorizontalAlign.Center);
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .backgroundColor($r('app.color.step_inactive'))
        .borderRadius(12)
        .height(54)
        .layoutWeight(1)
        .margin({ right: 8 })
        .onClick(() => this.pasteFromClipboard())
        .accessibilityText('从剪贴板粘贴')

        Button() {
          Row() {
            Column() {
              Text($r('app.string.index_start_button'))
                .fontSize(14)
                .fontColor($r('app.color.white'));
              Text('AI 模拟面试').fontSize(10)
                .fontColor($r('app.color.white')).opacity(0.7);
            }
            .alignItems(HorizontalAlign.Center);
            Text('▶').fontSize(16)
              .fontColor($r('app.color.white')).margin({ left: 6 });
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .backgroundColor($r('app.color.primary'))
        .borderRadius(12)
        .height(54)
        .layoutWeight(1)
        .enabled(this.jdText.trim().length > 0)
        .opacity(this.jdText.trim().length > 0 ? 1 : 0.45)
        .onClick(() => this.startInterview())
        .accessibilityText('开始面试');
      }
      .width('100%')
      .margin({ top: 16 });

      // ── 底部提示 ────────────────────────────
      Row() {
        Text('💡 步骤：').fontSize(12).fontColor($r('app.color.text_warning'))
          .margin({ right: 4 });
        Text('配置 API → 粘贴 JD → 开始面试')
          .fontSize(12).fontColor($r('app.color.text_tip'));
      }
      .width('100%').margin({ top: 20 });

      // ── API Key 状态卡片 ──────────────────────────
      Column() {
        Row() {
          Row() {
            Text(this.hasKey ? '✓' : '✗')
              .fontSize(16)
              .fontColor(this.hasKey ? $r('app.color.text_success') : $r('app.color.text_warning'))
              .margin({ right: 8 });
            Column() {
              Text(this.hasKey ? 'API Key 已配置' : '未配置 API Key')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'));
              if (!this.hasKey) {
                Text('点击下方「设置」前往配置')
                  .fontSize(12)
                  .fontColor($r('app.color.text_tip'))
                  .margin({ top: 2 });
              }
            }
            .alignItems(HorizontalAlign.Start);
          }
          .layoutWeight(1);

          Text('设置 ›')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_link'))
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor($r('app.color.primary_light'))
            .borderRadius(6)
            .onClick(() => this.goToSetting())
            .accessibilityText('打开设置页面');
        }
        .width('100%');

        // ── 模型快速选择行 ─────────────────────────
        if (this.modelOptions.length > 0) {
          Row() {
            Text('模型:')
              .fontSize(13)
              .fontColor($r('app.color.text_tip'))
              .margin({ right: 8 });

            Select(this.modelOptions)
              .selected(this.modelIndex).value(this.selectedModel)
              .font({ size: 13 }).height(36).layoutWeight(1)
              .fontColor($r('app.color.primary'))
              .optionFont({ size: 13 })
              .optionFontColor($r('app.color.text_primary'))
              .optionBgColor($r('app.color.card_background'))
              .selectedOptionFont({ size: 13, weight: FontWeight.Medium })
              .selectedOptionFontColor($r('app.color.primary'))
              .selectedOptionBgColor($r('app.color.primary_light'))
              .menuBackgroundColor($r('app.color.card_background'))
              .onSelect((index: number, value: string) => this.onModelSelected(index, value))
              .accessibilityText('切换模型');
          }
          .width('100%')
          .margin({ top: 10 });
        } else {
          Row() {
            Text('模型:')
              .fontSize(13)
              .fontColor($r('app.color.text_tip'))
              .margin({ right: 8 });
            Select([{ value: this.selectedModel || '选择模型' }])
              .selected(0).value(this.selectedModel || '选择模型')
              .font({ size: 13 }).layoutWeight(1)
              .fontColor($r('app.color.primary'))
              .optionFont({ size: 13 })
              .optionFontColor($r('app.color.text_primary'))
              .optionBgColor($r('app.color.card_background'))
              .selectedOptionFont({ size: 13, weight: FontWeight.Medium })
              .selectedOptionFontColor($r('app.color.primary'))
              .selectedOptionBgColor($r('app.color.primary_light'))
              .menuBackgroundColor($r('app.color.card_background'))
              .accessibilityText('切换模型');
          }
          .width('100%')
          .margin({ top: 10 });
        }

        // ── 余额信息行 ───────────────────────────
        if (this.balanceInfo.length > 0) {
          Row() {
            Text('💰')
              .fontSize(12)
              .margin({ right: 6 });
            Text(this.balanceInfo)
              .fontSize(12)
              .fontColor($r('app.color.text_tip'));
          }
          .width('100%')
          .margin({ top: 4 });
        }
      }
      .padding(16)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(12)
      .width('100%')
      .margin({ top: 28 })
      .shadow({
        radius: 8,
        color: $r('app.color.shadow_card'),
        offsetX: 0,
        offsetY: 2
      });
    }
    .padding({ left: 24, right: 24 })
    .height('100%')
    .width('100%')
    .constraintSize({ maxWidth: 600 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'));
  }
}
