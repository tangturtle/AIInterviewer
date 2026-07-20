import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getApiKey, getModel } from '../utils/PreferencesManager';
import {
  buildJDPrompt, parseJDResponse,
  buildQuestionPrompt, parseQuestionResponse,
  buildFollowUpPrompt,
  buildReportPrompt, parseReportResponse,
  parseFollowUpResponse,
  callLLMStream, reconstructResponse
} from '../utils/prompt';
import type { ParsedJD, InterviewQuestion, QAPair, InterviewReport, FollowUpItem } from '../utils/types';

@Component
export struct InterviewPage {
  navStack: NavPathStack = new NavPathStack();
  params: Record<string, Object> = {};

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
  @State streamingText: string = '';
  @State streamingReasoning: string = '';
  @State cursorVisible: boolean = true;
  private currentStreamRequest: http.HttpRequest | null = null;
  private cursorTimer: number = -1;

  private apiKey: string = '';
  private modelName: string = '';

  private readonly roundLabels: string[] = ['技术基础', '项目深度', '综合评估'];
  private readonly roundDescriptions: string[] = [
    '技能关键词考察',
    '项目经验深挖',
    '综合素质评估'
  ];

  aboutToAppear(): void {
    const jdTextParam = this.params?.jdText;
    if (!jdTextParam) {
      this.errorMessage = '缺少必要参数';
      this.pageState = 'error';
      return;
    }
    this.jdText = jdTextParam as string;
    this.startInterviewFlow();
  }

  aboutToDisappear(): void {
    this.destroyCurrentStream();
    if (this.cursorTimer >= 0) {
      clearInterval(this.cursorTimer);
      this.cursorTimer = -1;
    }
  }

  private startCursorBlink(): void {
    if (this.cursorTimer >= 0) { clearInterval(this.cursorTimer); }
    this.cursorVisible = true;
    this.cursorTimer = setInterval((): void => {
      this.cursorVisible = !this.cursorVisible;
    }, 530);
  }

  private stopCursorBlink(): void {
    if (this.cursorTimer >= 0) {
      clearInterval(this.cursorTimer);
      this.cursorTimer = -1;
    }
    this.cursorVisible = false;
  }

  private destroyCurrentStream(): void {
    if (this.currentStreamRequest) {
      try { this.currentStreamRequest.destroy(); } catch (_e) { /* ignore */ }
      this.currentStreamRequest = null;
    }
  }

  private clearStreamState(): void {
    this.streamingText = '';
    this.streamingReasoning = '';
    this.stopCursorBlink();
  }

  private getQuestionTypeBgColor(): Resource {
    if (this.currentQuestion === null) {
      return $r('app.color.badge_technical_bg');
    }
    const qType = this.currentQuestion.type;
    if (qType === 'technical') {
      return $r('app.color.badge_technical_bg');
    } else if (qType === 'behavioral') {
      return $r('app.color.badge_behavioral_bg');
    }
    return $r('app.color.badge_project_bg');
  }

  private getQuestionTypeTextColor(): Resource {
    if (this.currentQuestion === null) {
      return $r('app.color.badge_technical_text');
    }
    const qType = this.currentQuestion.type;
    if (qType === 'technical') {
      return $r('app.color.badge_technical_text');
    } else if (qType === 'behavioral') {
      return $r('app.color.badge_behavioral_text');
    }
    return $r('app.color.badge_project_text');
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

  private async startInterviewFlow(): Promise<void> {
    this.apiKey = (await getApiKey(getContext(this))) || '';
    this.modelName = await getModel(getContext(this));
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
    this.clearStreamState();
    const D = 0x0000;
    hilog.info(D, 'AIInterviewer', 'parseJD: 发送流式LLM请求');
    await this.streamCall(async () => {
      const { request, result } = callLLMStream(this.apiKey, '你是一个专业的职位解析助手。', buildJDPrompt(this.jdText), {
        onContent: (text: string): void => {
          this.pageState = 'streaming';
          this.streamingText = text;
          this.startCursorBlink();
        },
        onReasoning: (text: string): void => {
          this.streamingReasoning = text;
        }
      }, undefined, this.modelName);
      this.currentStreamRequest = request;
      const fullContent = await result;
      this.stopCursorBlink();
      const wrapped = reconstructResponse(fullContent);
      const jd = parseJDResponse(wrapped);
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
    this.clearStreamState();
    if (this.parsedJD === null) { return; }
    await this.streamCall(async () => {
      const { request, result } = callLLMStream(this.apiKey, '你是一个专业的面试官。',
        buildQuestionPrompt(this.parsedJD!, this.currentRound), {
        onContent: (text: string): void => {
          this.pageState = 'streaming';
          this.streamingText = text;
          this.startCursorBlink();
        },
        onReasoning: (text: string): void => {
          this.streamingReasoning = text;
        }
      }, undefined, this.modelName);
      this.currentStreamRequest = request;
      const fullContent = await result;
      this.stopCursorBlink();
      const wrapped = reconstructResponse(fullContent);
      const q = parseQuestionResponse(wrapped);
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
    this.clearStreamState();
    if (this.currentQuestion === null) { return; }
    await this.streamCall(async () => {
      const { request, result } = callLLMStream(this.apiKey, '你是一个专业的面试官。',
        buildFollowUpPrompt(this.currentQuestion!, this.currentAnswer, this.qaHistory), {
        onContent: (text: string): void => {
          this.pageState = 'streaming';
          this.streamingText = text;
          this.startCursorBlink();
        },
        onReasoning: (text: string): void => {
          this.streamingReasoning = text;
        }
      }, undefined, this.modelName);
      this.currentStreamRequest = request;
      const fullContent = await result;
      this.stopCursorBlink();
      const wrapped = reconstructResponse(fullContent);
      const parsed = parseFollowUpResponse(wrapped);
      if (parsed === null || parsed.length === 0) {
        throw new Error('追问生成失败');
      }
      this.followUpQuestion = parsed;
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
    this.clearStreamState();
    if (this.parsedJD === null) { return; }
    await this.streamCall(async () => {
      const { request, result } = callLLMStream(this.apiKey, '你是一个专业的面试评估专家。',
        buildReportPrompt(this.qaHistory, this.parsedJD!), {
        onContent: (text: string): void => {
          this.pageState = 'streaming';
          this.streamingText = text;
          this.startCursorBlink();
        },
        onReasoning: (text: string): void => {
          this.streamingReasoning = text;
        }
      }, undefined, this.modelName);
      this.currentStreamRequest = request;
      const fullContent = await result;
      this.stopCursorBlink();
      const wrapped = reconstructResponse(fullContent);
      const report = parseReportResponse(wrapped);
      if (report === null) {
        throw new Error('报告生成失败');
      }
      const reportParam: Record<string, Object> = { 'reportJson': JSON.stringify(report) };
      const reportPath: NavPathInfo = { name: 'Report', param: reportParam };
      this.navStack.replacePath(reportPath);
    });
  }

  private async streamCall(fn: () => Promise<void>): Promise<void> {
    while (this.retryCount < 3) {
      try {
        await fn();
        return;
      } catch (err) {
        this.destroyCurrentStream();
        this.retryCount++;
        if (this.retryCount >= 3) {
          this.errorMessage = '请求失败，请检查网络连接和 API Key 是否正确';
          const D = 0x0000;
          const errMsg = (err as Error).message || JSON.stringify(err);
          if (errMsg.includes('timeout') || errMsg.includes('Timeout') || errMsg.includes('28')) {
            this.errorMessage = '网络请求超时，请检查网络连接或更换 API 端点';
          }
          hilog.error(D, 'AIInterviewer', 'streamCall: 3次失败, error=%{public}s', errMsg);
          this.pageState = 'error';
          return;
        }
        await new Promise<string>((resolve) => {
          setTimeout((): void => {
            resolve('');
          }, 500);
        });
      }
    }
  }

  private goBack(): void {
    this.destroyCurrentStream();
    this.navStack.pop();
  }

  private retry(): void {
    this.destroyCurrentStream();
    this.retryCount = 0;
    this.pageState = 'loading_jd';
    this.parseJD();
  }

  build() {
    NavDestination() {
      Column() {
        if (this.pageState === 'loading_jd' || this.pageState === 'loading_question' ||
            this.pageState === 'loading_followup' || this.pageState === 'loading_report') {
          this.LoadingView();
        } else if (this.pageState === 'streaming') {
          this.StreamingView();
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
      .constraintSize({ maxWidth: 600 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor($r('app.color.page_background'))
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      if (context?.pathInfo?.param) {
        this.params = context.pathInfo.param as Record<string, Object>;
        // 如果 aboutToAppear 已经执行过 params 为空，重新触发初始化
        if (!this.params?.jdText && !this.jdText) {
          this.jdText = this.params.jdText as string;
          this.startInterviewFlow();
        }
      }
    });
  }

  @Builder
  LoadingView(): void {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color($r('app.color.loading_progress'));
      Text(this.getLoadingText())
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 20 });
      Text('请耐心等待，AI 正在思考...')
        .fontSize(12)
        .fontColor($r('app.color.text_tip'))
        .margin({ top: 8 });
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
  StreamingView(): void {
    Scroll() {
      Column() {
        if (this.streamingReasoning.length > 0) {
          Text('💭 ' + this.streamingReasoning)
            .fontSize(12)
            .fontColor($r('app.color.text_tip'))
            .backgroundColor($r('app.color.card_background_light'))
            .padding(12)
            .borderRadius(8)
            .width('100%')
            .lineHeight(20)
            .margin({ bottom: 16 });
        }

        Column() {
          Text(this.streamingText)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(26)
            .width('100%');

          if (this.streamingText.length > 0) {
            Text(this.cursorVisible ? '▊' : '')
              .fontSize(16)
              .fontColor($r('app.color.primary'))
              .margin({ left: 2 });
          }
        }
        .padding(20)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(14)
        .width('100%')
        .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 });

        // 加载中提示（流式文本还为空时显示）
        if (this.streamingText.length === 0) {
          Column() {
            LoadingProgress()
              .width(36).height(36)
              .color($r('app.color.loading_progress'));
            Text('AI 正在生成...')
              .fontSize(14).fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 });
          }
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height(120);
        }
      }
      .padding(20)
      .width('100%');
    }
  }

  @Builder
  QuestionView(): void {
    Scroll() {
      Column() {
        this.RoundProgressCard();

        Column() {
          Text(this.getQuestionTypeLabel())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getQuestionTypeTextColor())
            .backgroundColor(this.getQuestionTypeBgColor())
            .borderRadius(4)
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .margin({ bottom: 12 });

          Text(this.getQuestionText())
            .fontSize(17)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(27)
            .width('100%');

          if (this.getQuestionFocusArea().length > 0) {
            Row() {
              Text('●')
                .fontSize(8)
                .fontColor($r('app.color.text_tip'))
                .margin({ right: 6 });
              Text('考察：' + this.getQuestionFocusArea())
                .fontSize(13)
                .fontColor($r('app.color.text_tip'));
            }
            .margin({ top: 14 })
            .width('100%');
          }
        }
        .padding(20)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(14)
        .width('100%')
        .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 });

        TextArea({
          text: this.currentAnswer,
          placeholder: '请输入你的回答...'
        })
          .height(160)
          .borderRadius(12)
          .borderColor($r('app.color.border'))
          .borderWidth(1)
          .padding(14)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.input_background'))
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.currentAnswer = value;
          })
          .accessibilityText('输入你的回答')

        Button() {
          Row() {
            Text('✓').fontSize(14).margin({ right: 6 });
            Text('提交回答').fontSize(15);
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .backgroundColor($r('app.color.primary'))
        .fontColor($r('app.color.white'))
        .borderRadius(10)
        .height(48)
        .width('100%')
        .margin({ top: 14 })
        .enabled(this.currentAnswer.trim().length > 0)
        .opacity(this.currentAnswer.trim().length > 0 ? 1 : 0.45)
        .onClick(() => this.submitAnswer(this.currentAnswer))
        .accessibilityText('提交回答');
      }
      .padding(20)
      .width('100%');
    }
  }

  @Builder
  RoundProgressCard(): void {
    Row() {
      ForEach([1, 2, 3], (i: number) => {
        if (i > 1) {
          Divider()
            .height(2)
            .backgroundColor(i - 1 <= this.currentRound ? $r('app.color.step_active') : $r('app.color.divider'))
            .width(28);
        }
        Column() {
          Text('' + i)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(i < this.currentRound ? $r('app.color.white') :
              i === this.currentRound ? $r('app.color.white') : $r('app.color.step_inactive_text'))
            .width(26)
            .height(26)
            .textAlign(TextAlign.Center)
            .backgroundColor(i < this.currentRound ? $r('app.color.step_completed') :
              i === this.currentRound ? $r('app.color.step_active') : $r('app.color.step_inactive'))
            .borderRadius(13);
          Text(this.roundLabels[i - 1])
            .fontSize(11)
            .fontColor(i <= this.currentRound ? $r('app.color.text_primary') : $r('app.color.text_tip'))
            .margin({ top: 4 });
          Text(this.roundDescriptions[i - 1])
            .fontSize(10)
            .fontColor($r('app.color.text_tip'))
            .margin({ top: 1 });
        }
        .alignItems(HorizontalAlign.Center);
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(16)
    .backgroundColor($r('app.color.card_background_light'))
    .borderRadius(12)
    .margin({ bottom: 16 });
  }

  @Builder
  FollowUpView(): void {
    Scroll() {
      Column() {
        // ── 轮次语境指示条 ──────────────────────────
        Row() {
          Text('第 ' + this.currentRound + '/3 轮')
            .fontSize(12).fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.white'))
            .backgroundColor($r('app.color.primary'))
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 });

          Text(this.roundLabels[this.currentRound - 1])
            .fontSize(12).fontColor($r('app.color.text_tip'))
            .margin({ left: 8 });
        }
        .width('100%')
        .margin({ bottom: 12 });

        // ── 追问卡片（使用 borderLeft 替代内嵌 Column 色条） ──
        Column() {
          Text('追问')
            .fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.followup_accent'))
            .width('100%')
            .margin({ bottom: 10 });

          Text(this.followUpQuestion)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(26)
            .width('100%');
        }
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .width('100%')
        .backgroundColor($r('app.color.followup_bg'))
        .borderRadius(12)
        .borderColor($r('app.color.followup_border'))
        .borderWidth(1)
        .borderStyle(BorderStyle.Solid)
        .margin({ bottom: 20 });

        // ── 你的回答区 ──────────────────────────────
        Text('你的回答')
          .fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .margin({ bottom: 8 });

        TextArea({
          text: this.followUpAnswer,
          placeholder: '请输入你的回答...'
        })
          .height(140)
          .borderRadius(12)
          .borderColor($r('app.color.border'))
          .borderWidth(1)
          .padding(14)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.input_background'))
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.followUpAnswer = value;
          })
          .accessibilityText('输入追问的回答')

        Button() {
          Row() {
            Text('✓').fontSize(14).margin({ right: 6 });
            Text('提交回答').fontSize(15);
          }
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .backgroundColor($r('app.color.primary'))
        .fontColor($r('app.color.white'))
        .borderRadius(10)
        .height(48)
        .width('100%')
        .enabled(this.followUpAnswer.trim().length > 0)
        .opacity(this.followUpAnswer.trim().length > 0 ? 1 : 0.45)
        .onClick(() => this.submitFollowUpAnswer(this.followUpAnswer))
        .accessibilityText('提交追问回答');

        Text('按 Enter 快速提交 · Ctrl+Enter 换行')
          .fontSize(11).fontColor($r('app.color.text_tip'))
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 8 });
      }
      .padding(20)
      .width('100%');
    }
  }

  @Builder
  ErrorView(): void {
    Column() {
      Text('!')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_danger'))
        .width(72)
        .height(72)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.error_bg'))
        .borderRadius(36)
        .margin({ bottom: 20 });

      Text(this.errorMessage)
        .fontSize(16)
        .fontColor($r('app.color.text_danger'))
        .textAlign(TextAlign.Center)
        .margin({ bottom: 28 });

      Row() {
        Button('🔄 重试')
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .borderRadius(10)
          .height(48)
          .layoutWeight(1)
          .margin({ right: 8 })
          .borderColor($r('app.color.border'))
          .borderWidth(1)
          .onClick(() => this.retry())
          .accessibilityText('重试');

        Button('返回首页')
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.white'))
          .borderRadius(10)
          .height(48)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => this.goBack())
          .accessibilityText('返回首页');
      }
      .width('100%');
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%')
    .padding(24);
  }
}
