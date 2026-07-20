import { hilog } from '@kit.PerformanceAnalysisKit';
import type { InterviewReport } from '../utils/types';

@Component
export struct ReportPage {
  navStack: NavPathStack = new NavPathStack();
  params: Record<string, Object> = {};

  @State report: InterviewReport | null = null;

  aboutToAppear(): void {
    const reportJson = this.params?.reportJson;
    if (reportJson) {
      try {
        const parsed = JSON.parse(reportJson as string) as InterviewReport;
        this.report = parsed;
      } catch (err) {
        hilog.error(0x0000, 'AIInterviewer', 'Report aboutToAppear parse error: %{public}s', JSON.stringify(err));
      }
    }
  }

  private getScoreColor(score: number): Resource {
    if (score >= 90) { return $r('app.color.score_excellent'); }
    else if (score >= 75) { return $r('app.color.score_good'); }
    else if (score >= 60) { return $r('app.color.score_average'); }
    return $r('app.color.score_poor');
  }

  private getScoreLevel(score: number): string {
    if (score >= 90) { return '优秀'; }
    else if (score >= 75) { return '良好'; }
    else if (score >= 60) { return '一般'; }
    return '需加强';
  }

  private getDimLabel(key: string): string {
    if (key === 'technical') { return '技术深度'; }
    else if (key === 'expression') { return '表达沟通'; }
    else if (key === 'logic') { return '逻辑思维'; }
    return '';
  }

  private getDimScore(key: string): number {
    if (this.report === null) { return 0; }
    if (key === 'technical') { return this.report.dimensions.technical.score; }
    else if (key === 'expression') { return this.report.dimensions.expression.score; }
    else if (key === 'logic') { return this.report.dimensions.logic.score; }
    return 0;
  }

  private getDimComment(key: string): string {
    if (this.report === null) { return ''; }
    if (key === 'technical') { return this.report.dimensions.technical.comment; }
    else if (key === 'expression') { return this.report.dimensions.expression.comment; }
    else if (key === 'logic') { return this.report.dimensions.logic.comment; }
    return '';
  }

  private getDimSuggestions(key: string): string[] {
    if (this.report === null) { return []; }
    if (key === 'technical') { return this.report.dimensions.technical.suggestions; }
    else if (key === 'expression') { return this.report.dimensions.expression.suggestions; }
    else if (key === 'logic') { return this.report.dimensions.logic.suggestions; }
    return [];
  }

  private restartInterview(): void {
    this.navStack.pop();
  }

  build() {
    NavDestination() {
      Column() {
        if (this.report === null) {
          this.EmptyStateView();
        } else {
          this.ReportContent();
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
        if (this.params?.reportJson && !this.report) {
          try {
            this.report = JSON.parse(this.params.reportJson as string) as InterviewReport;
          } catch (err) {
            hilog.error(0x0000, 'AIInterviewer', 'Report onReady parse error: %{public}s', JSON.stringify(err));
          }
        }
      }
    });
  }

  @Builder
  EmptyStateView(): void {
    Column() {
      Text('📊').fontSize(48).margin({ bottom: 16 });
      Text('暂无报告数据').fontSize(16).fontColor($r('app.color.text_tip'));
      Button('返回首页')
        .backgroundColor($r('app.color.primary')).fontColor($r('app.color.white'))
        .borderRadius(10).height(48).width(160).margin({ top: 20 })
        .onClick(() => this.restartInterview()).accessibilityText('返回首页');
    }
    .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
    .height('100%').width('100%');
  }

  @Builder
  ReportContent(): void {
    Scroll() {
      Column() {
        Text('面试评估报告')
          .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          .width('100%').margin({ top: 24, bottom: 20 });

        this.ScoreGaugeComponent();
        this.DimensionCardComponent('technical');
        this.DimensionCardComponent('expression');
        this.DimensionCardComponent('logic');
        this.SummaryCardComponent();

        Button() {
          Row() {
            Text('🔄').fontSize(16).margin({ right: 8 });
            Text('再来一次').fontSize(16);
          }
          .alignItems(VerticalAlign.Center).justifyContent(FlexAlign.Center)
        }
        .backgroundColor($r('app.color.primary')).fontColor($r('app.color.white'))
        .borderRadius(10).height(50).width('100%').margin({ top: 8, bottom: 32 })
        .onClick(() => this.restartInterview()).accessibilityText('重新开始面试');
      }
      .padding({ left: 20, right: 20 }).width('100%');
    }
  }

  @Builder
  ScoreGaugeComponent(): void {
    Column() {
      Column() {
        Text('综合评分').fontSize(14).fontColor($r('app.color.text_tip')).margin({ bottom: 12 });
        Column() {
          Text('' + this.getOverallScore())
            .fontSize(48).fontWeight(FontWeight.Bold).fontColor(this.getScoreColor(this.getOverallScore()));
          Text(this.getScoreLevel(this.getOverallScore()))
            .fontSize(14).fontColor(this.getScoreColor(this.getOverallScore())).margin({ top: 4 });
        }
        .width(120).height(120).alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        .border({ width: 6, color: this.getScoreColor(this.getOverallScore()) }).borderRadius(60);
      }
      .alignItems(HorizontalAlign.Center);
    }
    .padding(24).backgroundColor($r('app.color.card_background')).borderRadius(16)
    .width('100%').alignItems(HorizontalAlign.Center).margin({ bottom: 16 })
    .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 });
  }

  private getOverallScore(): number {
    return this.report?.overall ?? 0;
  }

  @Builder
  DimensionCardComponent(key: string): void {
    Column() {
      Row() {
        Text(this.getDimLabel(key)).fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'));
        Text('' + this.getDimScore(key) + '分').fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor(this.getDimScore(key)));
      }
      .width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 8 });

      Progress({ value: Math.min(this.getDimScore(key), 100), total: 100, type: ProgressType.Linear })
        .height(6).width('100%').value(Math.min(this.getDimScore(key), 100))
        .color(this.getScoreColor(this.getDimScore(key)))
        .backgroundColor($r('app.color.step_inactive')).borderRadius(3).margin({ bottom: 12 });

      Text(this.getDimComment(key)).fontSize(14).fontColor($r('app.color.text_secondary'))
        .lineHeight(22).width('100%').margin({ bottom: 12 });

      this.SuggestionsPanel(key);
    }
    .padding(16).backgroundColor($r('app.color.card_background')).borderRadius(14)
    .width('100%').margin({ bottom: 12 })
    .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });
  }

  @Builder
  SuggestionsPanel(key: string): void {
    if (this.getDimSuggestions(key).length > 0) {
      Column() {
        Text('改进建议').fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_warning')).width('100%').margin({ bottom: 10 });
        ForEach(this.getDimSuggestions(key), (sug: string) => {
          Row() {
            Text('✦').fontSize(11).fontColor($r('app.color.text_warning')).margin({ right: 8, top: 2 });
            Text(sug).fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20);
          }
          .alignItems(VerticalAlign.Top).margin({ bottom: 6 });
        })
      }
      .width('100%').padding(14).backgroundColor($r('app.color.suggestions_bg')).borderRadius(10);
    }
  }

  @Builder
  SummaryCardComponent(): void {
    Column() {
      Text('综合评价').fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%').margin({ bottom: 10 });
      Row() {
        Text('"').fontSize(24).fontColor($r('app.color.primary')).fontWeight(FontWeight.Bold)
          .margin({ right: 6, top: -4 });
        Text(this.getSummaryText()).fontSize(14).fontColor($r('app.color.text_secondary'))
          .lineHeight(22).layoutWeight(1);
        Text('"').fontSize(24).fontColor($r('app.color.primary')).fontWeight(FontWeight.Bold)
          .margin({ left: 6, top: -4 });
      }
      .alignItems(VerticalAlign.Top).width('100%');
    }
    .padding(18).backgroundColor($r('app.color.card_background')).borderRadius(14)
    .width('100%').margin({ bottom: 16 })
    .shadow({ radius: 4, color: '#08000000', offsetX: 0, offsetY: 1 });
  }

  private getSummaryText(): string {
    return this.report?.summary ?? '';
  }
}
