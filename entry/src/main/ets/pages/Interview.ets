@Entry
@Component
struct Interview {
  @State pageState: string = 'loading_jd';
  @State jdText: string = '';
  @State parsedJD: object | null = null;
  @State currentRound: number = 1;
  @State currentQuestion: object | null = null;
  @State currentAnswer: string = '';
  @State followUpQuestion: string = '';
  @State followUpAnswer: string = '';
  @State qaHistory: object[] = [];
  @State errorMessage: string = '';
  @State retryCount: number = 0;

  private apiKey: string = '';

  aboutToAppear(): void {
    const { router } = require('@kit.AbilityKit');
    const params = router.getParams() as Record<string, Object>;
    if (!params || !params.jdText) {
      this.errorMessage = '缺少必要参数';
      this.pageState = 'error';
      return;
    }
    this.jdText = params.jdText as string;
    this.startInterviewFlow();
  }

  private async startInterviewFlow(): Promise<void> {
    // Step 1: 从 Preferences 获取 API Key
    const { getApiKey } = require('../utils/PreferencesManager');
    this.apiKey = (await getApiKey(getContext())) || '';
    if (!this.apiKey) {
      this.errorMessage = '请先配置 API Key';
      this.pageState = 'error';
      return;
    }

    // Step 2: 解析 JD
    await this.parseJD();
  }

  private async parseJD(): Promise<void> {
    this.pageState = 'loading_jd';
    this.retryCount = 0;
    await this.callWithRetry(async () => {
      const { buildJDPrompt, parseJDResponse, callLLM } = require('../utils/prompt');
      const raw = await callLLM(this.apiKey, '你是一个专业的职位解析助手。', buildJDPrompt(this.jdText));
      const jd = parseJDResponse(raw);
      if (!jd) {
        throw new Error('JD解析失败');
      }
      this.parsedJD = jd;
      await this.generateQuestion();
    });
  }

  private async generateQuestion(): Promise<void> {
    this.pageState = 'loading_question';
    this.retryCount = 0;
    await this.callWithRetry(async () => {
      const { buildQuestionPrompt, parseQuestionResponse, callLLM } = require('../utils/prompt');
      const raw = await callLLM(this.apiKey, '你是一个专业的面试官。',
        buildQuestionPrompt(this.parsedJD as Record<string, Object>, this.currentRound));
      const q = parseQuestionResponse(raw);
      if (!q) {
        throw new Error('题目解析失败');
      }
      this.currentQuestion = q;
      this.currentAnswer = '';
      this.pageState = 'awaiting_answer';
    });
  }

  private submitAnswer(answer: string): void {
    if (!answer.trim()) {
      return;
    }
    this.currentAnswer = answer;
    this.generateFollowUp();
  }

  private async generateFollowUp(): Promise<void> {
    this.pageState = 'loading_followup';
    this.retryCount = 0;
    await this.callWithRetry(async () => {
      const { buildFollowUpPrompt, callLLM } = require('../utils/prompt');
      const followUp = await callLLM(this.apiKey, '你是一个专业的面试官。',
        buildFollowUpPrompt(
          this.currentQuestion as Record<string, Object>,
          this.currentAnswer,
          this.qaHistory as Record<string, Object>[]
        ));
      if (!followUp || followUp.length === 0) {
        throw new Error('追问生成失败');
      }
      this.followUpQuestion = followUp;
      this.followUpAnswer = '';
      this.pageState = 'awaiting_followup_answer';
    });
  }

  private submitFollowUpAnswer(answer: string): void {
    if (!answer.trim()) {
      return;
    }
    this.followUpAnswer = answer;

    // 将本轮问答存入历史
    const qaEntry = {
      question: this.currentQuestion,
      answer: this.currentAnswer,
      followUps: [{ question: this.followUpQuestion, answer: this.followUpAnswer }]
    };
    const newHistory = [...this.qaHistory, qaEntry];
    this.qaHistory = newHistory;

    if (this.currentRound < 3) {
      this.currentRound++;
      this.generateQuestion();
    } else {
      this.generateReport();
    }
  }

  private async generateReport(): Promise<void> {
    this.pageState = 'loading_report';
    this.retryCount = 0;
    await this.callWithRetry(async () => {
      const { buildReportPrompt, parseReportResponse, callLLM } = require('../utils/prompt');
      const raw = await callLLM(this.apiKey, '你是一个专业的面试评估专家。',
        buildReportPrompt(
          this.qaHistory as Record<string, Object>[],
          this.parsedJD as Record<string, Object>
        ));
      const report = parseReportResponse(raw);
      if (!report) {
        throw new Error('报告解析失败');
      }
      // 跳转到报告页
      const { router } = require('@kit.AbilityKit');
      router.replaceUrl({
        url: 'pages/Report',
        params: {
          reportJson: JSON.stringify(report)
        }
      });
    });
  }

  private async callWithRetry(fn: () => Promise<void>): Promise<void> {
    while (this.retryCount < 3) {
      try {
        await fn();
        return;
      } catch (err) {
        this.retryCount++;
        if (this.retryCount >= 3) {
          this.errorMessage = '请求失败，请检查网络连接和 API Key 是否正确';
          this.pageState = 'error';
          return;
        }
        // 自动重试（短暂延迟）
        await new Promise(r => setTimeout(r, 500));
      }
    }
  }

  private goBack(): void {
    const { router } = require('@kit.AbilityKit');
    router.back();
  }

  build() {
    Column() {
      if (this.pageState === 'loading_jd' || this.pageState === 'loading_question' ||
          this.pageState === 'loading_followup' || this.pageState === 'loading_report') {
        this.LoadingView();
      } else if (this.pageState === 'awaiting_answer' && this.currentQuestion) {
        this.QuestionView();
      } else if (this.pageState === 'awaiting_followup_answer') {
        this.FollowUpView();
      } else if (this.pageState === 'error') {
        this.ErrorView();
      }
    }
    .height('100%')
    .width('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  LoadingView(): void {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#0A59F7');
      Text(this.getLoadingText())
        .fontSize(15)
        .fontColor('#666666')
        .margin({ top: 16 });
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%');
  }

  private getLoadingText(): string {
    const texts: Record<string, string> = {
      'loading_jd': '正在解析职位描述...',
      'loading_question': '正在生成面试题...',
      'loading_followup': '正在生成追问...',
      'loading_report': '正在生成评估报告...'
    };
    return texts[this.pageState] || '加载中...';
  }

  @Builder
  QuestionView(): void {
    Scroll() {
      Column() {
        // 进度指示
        Text(`第 ${this.currentRound}/3 题`)
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .margin({ bottom: 8 });

        // 进度条
        Row() {
          ForEach([1, 2, 3], (i: number) => {
            Row() {
              if (i > 1) {
                Divider()
                  .height(2)
                  .backgroundColor(i <= this.currentRound ? '#0A59F7' : '#E0E0E0')
                  .width(40);
              }
              Text(`${i}`)
                .fontSize(12)
                .fontColor(i <= this.currentRound ? Color.White : '#999999')
                .backgroundColor(i <= this.currentRound ? '#0A59F7' : '#F0F0F0')
                .width(24)
                .height(24)
                .borderRadius(12)
                .textAlign(TextAlign.Center);
            }
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 20 });

        // 题目卡片
        if (this.currentQuestion) {
          const q = this.currentQuestion as Record<string, Object>;
          const qType = q.type as string;
          const typeColor = qType === 'technical' ? '#007DFF' :
                            qType === 'behavioral' ? '#FF9500' : '#34C759';
          const typeLabel = qType === 'technical' ? '技术' :
                            qType === 'behavioral' ? '行为' : '项目';

          Column() {
            Row() {
              Text(typeLabel)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor(typeColor)
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 });
            }
            .width('100%')
            .margin({ bottom: 12 });

            Text(q.text as string)
              .fontSize(17)
              .fontColor('#333333')
              .lineHeight(26)
              .width('100%');

            if (q.focusArea) {
              Text(`考察维度：${q.focusArea as string}`)
                .fontSize(13)
                .fontColor('#999999')
                .margin({ top: 12 })
                .width('100%');
            }
          }
          .padding(16)
          .backgroundColor('#F8F9FA')
          .borderRadius(12)
          .width('100%');
        }

        // 回答输入
        TextArea({
          text: this.currentAnswer,
          placeholder: '请输入你的回答...'
        })
          .height(160)
          .borderRadius(12)
          .borderColor('#E0E0E0')
          .borderWidth(1)
          .padding(12)
          .fontSize(15)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.currentAnswer = value;
          });

        // 提交按钮
        Button('提交回答')
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .borderRadius(8)
          .height(44)
          .width('100%')
          .margin({ top: 12 })
          .enabled(this.currentAnswer.trim().length > 0)
          .opacity(this.currentAnswer.trim().length > 0 ? 1 : 0.5)
          .onClick(() => this.submitAnswer(this.currentAnswer));
      }
      .padding(20)
      .width('100%');
    }
  }

  @Builder
  FollowUpView(): void {
    Scroll() {
      Column() {
        Text('追问')
          .fontSize(14)
          .fontColor('#FF9500')
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .margin({ bottom: 12 });

        // 追问文本
        Text(this.followUpQuestion)
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(25)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFF8E1')
          .borderRadius(12);

        // 回答输入
        TextArea({
          text: this.followUpAnswer,
          placeholder: '请输入你的回答...'
        })
          .height(140)
          .borderRadius(12)
          .borderColor('#E0E0E0')
          .borderWidth(1)
          .padding(12)
          .fontSize(15)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.followUpAnswer = value;
          });

        // 提交按钮
        Button('提交回答')
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .borderRadius(8)
          .height(44)
          .width('100%')
          .margin({ top: 12 })
          .enabled(this.followUpAnswer.trim().length > 0)
          .opacity(this.followUpAnswer.trim().length > 0 ? 1 : 0.5)
          .onClick(() => this.submitFollowUpAnswer(this.followUpAnswer));
      }
      .padding(20)
      .width('100%');
    }
  }

  @Builder
  ErrorView(): void {
    Column() {
      Image($r('app.media.app_icon'))
        .width(64)
        .height(64)
        .margin({ bottom: 16 });

      Text(this.errorMessage)
        .fontSize(16)
        .fontColor('#FF3B30')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 24 });

      Button('返回首页')
        .backgroundColor('#0A59F7')
        .fontColor(Color.White)
        .borderRadius(8)
        .height(44)
        .width(160)
        .onClick(() => this.goBack());
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%')
    .padding(20);
  }
}
