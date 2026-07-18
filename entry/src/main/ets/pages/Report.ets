import router from '@ohos.router';
import type { InterviewReport } from '../utils/types';

@Entry
@Component
struct Report {
  @State report: InterviewReport | null = null;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.reportJson) {
      try {
        const parsed = JSON.parse(params.reportJson as string) as InterviewReport;
        this.report = parsed;
      } catch (err) {
        // 解析失败，report 保持 null
      }
    }
  }

  private getScoreColor(score: number): string {
    if (score >= 90) {
      return '#34C759';
    } else if (score >= 75) {
      return '#0A59F7';
    } else if (score >= 60) {
      return '#FF9500';
    }
    return '#FF3B30';
  }

  private getScoreLevel(score: number): string {
    if (score >= 90) {
      return '优秀';
    } else if (score >= 75) {
      return '良好';
    } else if (score >= 60) {
      return '一般';
    }
    return '需加强';
  }

  private getDimLabel(key: string): string {
    if (key === 'technical') {
      return '技术深度';
    } else if (key === 'expression') {
      return '表达沟通';
    } else if (key === 'logic') {
      return '逻辑思维';
    }
    return '';
  }

  private getDimScore(key: string): number {
    if (this.report === null) {
      return 0;
    }
    if (key === 'technical') {
      return this.report.dimensions.technical.score;
    } else if (key === 'expression') {
      return this.report.dimensions.expression.score;
    } else if (key === 'logic') {
      return this.report.dimensions.logic.score;
    }
    return 0;
  }

  private getDimComment(key: string): string {
    if (this.report === null) {
      return '';
    }
    if (key === 'technical') {
      return this.report.dimensions.technical.comment;
    } else if (key === 'expression') {
      return this.report.dimensions.expression.comment;
    } else if (key === 'logic') {
      return this.report.dimensions.logic.comment;
    }
    return '';
  }

  private getDimSuggestions(key: string): string[] {
    if (this.report === null) {
      return [];
    }
    if (key === 'technical') {
      return this.report.dimensions.technical.suggestions;
    } else if (key === 'expression') {
      return this.report.dimensions.expression.suggestions;
    } else if (key === 'logic') {
      return this.report.dimensions.logic.suggestions;
    }
    return [];
  }

  private restartInterview(): void {
    router.back();
  }

  build() {
    Column() {
      if (this.report === null) {
        Column() {
          Text('暂无报告数据')
            .fontSize(16)
            .fontColor('#999999');
          Button('返回首页')
            .backgroundColor('#0A59F7')
            .fontColor(Color.White)
            .borderRadius(8)
            .height(44)
            .width(160)
            .margin({ top: 20 })
            .onClick(() => this.restartInterview());
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .height('100%')
        .width('100%');
      } else {
        this.ReportContent();
      }
    }
    .height('100%')
    .width('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor($r('app.color.page_background'));
  }

  @Builder
  ReportContent(): void {
    Scroll() {
      Column() {
        Text('面试评估报告')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .width('100%')
          .margin({ top: 20, bottom: 20 });

        this.ScoreCardComponent();
        this.DimensionCardComponent('technical');
        this.DimensionCardComponent('expression');
        this.DimensionCardComponent('logic');
        this.SummaryComponent();

        Button('再来一次')
          .backgroundColor('#0A59F7')
          .fontColor(Color.White)
          .borderRadius(8)
          .height(48)
          .width('100%')
          .margin({ top: 8, bottom: 32 })
          .onClick(() => this.restartInterview());
      }
      .padding({ left: 20, right: 20 })
      .width('100%');
    }
  }

  @Builder
  ScoreCardComponent(): void {
    Column() {
      Text('综合评分')
        .fontSize(14)
        .fontColor('#999999')
        .margin({ bottom: 8 });

      Text('' + this.getOverallScore())
        .fontSize(56)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getScoreColor(this.getOverallScore()));

      Text(this.getScoreLevel(this.getOverallScore()))
        .fontSize(16)
        .fontColor(this.getScoreColor(this.getOverallScore()))
        .margin({ top: 4 });
    }
    .padding(20)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 16 });
  }

  private getOverallScore(): number {
    if (this.report === null) {
      return 0;
    }
    return this.report.overall;
  }

  @Builder
  DimensionCardComponent(key: string): void {
    Column() {
      Row() {
        Text(this.getDimLabel(key))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333');

        Text('' + this.getDimScore(key))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getScoreColor(this.getDimScore(key)));
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 8 });

      Text(this.getDimComment(key))
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(22)
        .width('100%')
        .margin({ bottom: 12 });

      this.SuggestionsComponent(key);
    }
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .width('100%')
    .margin({ bottom: 12 });
  }

  @Builder
  SuggestionsComponent(key: string): void {
    if (this.getDimSuggestions(key).length > 0) {
      Column() {
        Text('改进建议')
          .fontSize(13)
          .fontColor('#FF9500')
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 });

        ForEach(this.getDimSuggestions(key), (sug: string) => {
          Row() {
            Text('•')
              .fontSize(13)
              .fontColor('#FF9500')
              .margin({ right: 6 });
            Text(sug)
              .fontSize(13)
              .fontColor('#666666')
              .lineHeight(20);
          }
          .alignItems(VerticalAlign.Top)
          .margin({ bottom: 4 });
        })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.warning_bg'))
      .borderRadius(8);
    }
  }

  @Builder
  SummaryComponent(): void {
    Column() {
      Text('综合评价')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ bottom: 8 });

      Text(this.getSummaryText())
        .fontSize(14)
        .fontColor('#666666')
        .lineHeight(22);
    }
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(12)
    .width('100%')
    .margin({ bottom: 16 });
  }

  private getSummaryText(): string {
    if (this.report === null) {
      return '';
    }
    return this.report.summary;
  }
}
