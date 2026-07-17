import router from '@ohos.router';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getApiKey, getEndpoint, getModel } from '../utils/PreferencesManager';
import {
  buildJDPrompt, parseJDResponse,
  buildQuestionPrompt, parseQuestionResponse,
  buildFollowUpPrompt,
  buildReportPrompt, parseReportResponse,
  callLLM
} from '../utils/prompt';
import type { ParsedJD, InterviewQuestion, QAPair, InterviewReport, FollowUpItem } from '../utils/types';

@Entry
@Component
struct Interview {
  @State pageState: string = 'loading_jd';
  @State jdText: string = '';
  @State parsedJD: ParsedJD | null = null;
  @State currentRound: number = 1;
  @State currentQuestion: InterviewQuestion | null = null;
  @State currentAnswer: string = '';
  @State followUpQuestion: string = '';
  @State followUpAnswer: string = '';
  @State qaHistory: QAPair[] = [];
  @State errorMessage: string = '';
  @State retryCount: number = 0;

  private apiKey: string = '';
  private modelName: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (!params || !params.jdText) {
      this.errorMessage = '缺少必要参数';
      this.pageState = 'error';
      return;
    }
    this.jdText = params.jdText as string;
    this.startInterviewFlow();
  }

  // ── 计算属性辅助方法 ─────────────────────────────────

  private getQuestionTypeColor(): string {
    if (this.currentQuestion === null) {
      return '#007DFF';
    }
    const qType = this.currentQuestion.type;
    if (qType === 'technical') {
      return '#007DFF';
    } else if (qType === 'behavioral') {
      return '#FF9500';
    }
    return '#34C759';
  }

  private getQuestionTypeLabel(): string {
    if (this.currentQuestion === null) {
      return '技术';
    }
    const qType = this.currentQuestion.type;
    if (qType === 'technical') {
      return '技术';
    } else if (qType === 'behavioral') {
      return '行为';
    }
    return '项目';
  }

  private getQuestionText(): string {
    if (this.currentQuestion === null) {
      return '';
    }
    return this.currentQuestion.text;
  }

  private getQuestionFocusArea(): string {
    if (this.currentQuestion === null) {
      return '';
    }
    return this.currentQuestion.focusArea;
  }

  private isStepActive(step: number): boolean {
    return step <= this.currentRound;
  }

  private isStepCurrent(step: number): boolean {
    return step === this.currentRound;
  }

  // ── 业务流程 ────────────────────────────────────────

  private async startInterviewFlow(): Promise<void> {
    this.apiKey = (await getApiKey(getContext(this))) || '';
    this.modelName = await getModel(getContext(this));
    if (!this.modelName) {
      this.modelName = 'deepseek-v4-flash';
    }
    if (!this.apiKey) {
      this.errorMessage = '请先配置 API Key';
      this.pageState = 'error';
      return;
    }
    await this.parseJD();
  }

  private async parseJD(): Promise<void> {
    this.pageState = 'loading_jd';
    this.retryCount = 0;
    await this.callWithRetry(async () => {
      const D = 0x0000;
      hilog.info(D, 'AIInterviewer', 'parseJD: 发送LLM请求');
      const raw = await callLLM(this.apiKey, '你是一个专业的职位解析助手。', buildJDPrompt(this.jdText), undefined, this.modelName);
      const jd = parseJDResponse(raw);
      if (jd === null) {
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
      if (this.parsedJD === null) {
        throw new Error('JD 未解析');
      }
      const raw = await callLLM(this.apiKey, '你是一个专业的面试官。',
        buildQuestionPrompt(this.parsedJD, this.currentRound), undefined, this.modelName);
      const q = parseQuestionResponse(raw);
      if (q === null) {
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
      if (this.currentQuestion === null) {
        throw new Error('无当前题目');
      }
      const followUp = await callLLM(this.apiKey, '你是一个专业的面试官。',
        buildFollowUpPrompt(this.currentQuestion, this.currentAnswer, this.qaHistory), undefined, this.modelName);
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

    if (this.currentQuestion === null) {
      return;
    }

    const followUpItem: FollowUpItem = {
      question: this.followUpQuestion,
      answer: this.followUpAnswer
    };
    const qaEntry: QAPair = {
      question: this.currentQuestion,
      answer: this.currentAnswer,
      followUps: [followUpItem]
    };
    const newHistory: QAPair[] = [];
    for (let i = 0; i < this.qaHistory.length; i++) {
      newHistory.push(this.qaHistory[i]);
    }
    newHistory.push(qaEntry);
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
      if (this.parsedJD === null) {
        throw new Error('JD 未解析');
      }
      const raw = await callLLM(this.apiKey, '你是一个专业的面试评估专家。',
        buildReportPrompt(this.qaHistory, this.parsedJD), undefined, this.modelName);
      const report = parseReportResponse(raw);
      if (report === null) {
        throw new Error('报告解析失败');
      }
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
          const D = 0x0000;
          const errMsg = (err as Error).message || JSON.stringify(err);
          if (errMsg.includes('timeout') || errMsg.includes('Timeout') || errMsg.includes('28')) {
            this.errorMessage = '网络请求超时，请检查网络连接或更换 API 端点';
          }
          hilog.error(D, 'AIInterviewer', 'callWithRetry: 3次失败, error=%{public}s', errMsg);
          this.pageState = 'error';
          return;
        }
        // 自动重试
        await new Promise<string>((resolve) => {
          setTimeout((): void => {
            resolve('');
          }, 500);
        });
      }
    }
  }

  private goBack(): void {
    router.back();
  }

  // ── UI 构建 ──────────────────────────────────────────

  build() {
    Column() {
      if (this.pageState === 'loading_jd' || this.pageState === 'loading_question' ||
          this.pageState === 'loading_followup' || this.pageState === 'loading_report') {
        this.LoadingView();
      } else if (this.pageState === 'awaiting_answer' && this.currentQuestion !== null) {
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
    if (this.pageState === 'loading_jd') {
      return '正在解析职位描述...';
    } else if (this.pageState === 'loading_question') {
      return '正在生成面试题...';
    } else if (this.pageState === 'loading_followup') {
      return '正在生成追问...';
    } else if (this.pageState === 'loading_report') {
      return '正在生成评估报告...';
    }
    return '加载中...';
  }

  @Builder
  QuestionView(): void {
    Scroll() {
      Column() {
        // 进度指示
        Text('第 ' + this.currentRound + '/3 题')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .margin({ bottom: 8 });

        this.ProgressBarComponent();

        // 题目卡片
        Column() {
          Row() {
            Text(this.getQuestionTypeLabel())
              .fontSize(12)
              .fontColor(Color.White)
              .backgroundColor(this.getQuestionTypeColor())
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 });
          }
          .width('100%')
          .margin({ bottom: 12 });

          Text(this.getQuestionText())
            .fontSize(17)
            .fontColor('#333333')
            .lineHeight(26)
            .width('100%');

          if (this.getQuestionFocusArea().length > 0) {
            Text('考察维度：' + this.getQuestionFocusArea())
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
  ProgressBarComponent(): void {
    Row() {
      ForEach([1, 2, 3], (i: number) => {
        Row() {
          if (i > 1) {
            Divider()
              .height(2)
              .backgroundColor(this.isStepActive(i) ? '#0A59F7' : '#E0E0E0')
              .width(40);
          }
          Text('' + i)
            .fontSize(12)
            .fontColor(this.isStepActive(i) ? Color.White : '#999999')
            .backgroundColor(this.isStepActive(i) ? '#0A59F7' : '#F0F0F0')
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

        Text(this.followUpQuestion)
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(25)
          .width('100%')
          .padding(16)
          .backgroundColor('#FFF8E1')
          .borderRadius(12);

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
      Text('❌')
        .fontSize(48)
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
