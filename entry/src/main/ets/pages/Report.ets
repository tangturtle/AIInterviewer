@Entry
@Component
struct Report {
  @State report: object | null = null;

  aboutToAppear(): void {
    const { router } = require('@kit.AbilityKit');
    const params = router.getParams() as Record<string, Object>;
    if (params && params.reportJson) {
      try {
        this.report = JSON.parse(params.reportJson as string);
      } catch (err) {
        // 解析失败，report 保持 null
      }
    }
  }

  private getScoreColor(score: number): string {
    if (score >= 90) return '#34C759';
    if (score >= 75) return '#0A59F7';
    if (score >= 60) return '#FF9500';
    return '#FF3B30';
  }

  private getScoreLevel(score: number): string {
    if (score >= 90) return '优秀';
    if (score >= 75) return '良好';
    if (score >= 60) return '一般';
    return '需加强';
  }

  private restartInterview(): void {
    const { router } = require('@kit.AbilityKit');
    router.back();
  }

  build() {
    Column() {
      if (!this.report) {
        // 无报告数据
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
    .backgroundColor('#F5F5F5');
  }

  @Builder
  ReportContent(): void {
    const r = this.report as Record<string, Object>;
    const overall = r.overall as number;
    const dims = r.dimensions as Record<string, Object>;
    const dimNames: Record<string, string> = {
      'technical': '技术深度',
      'expression': '表达沟通',
      'logic': '逻辑思维'
    };

    Scroll() {
      Column() {
        // 标题
        Text('面试评估报告')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .width('100%')
          .margin({ top: 20, bottom: 20 });

        // 总分卡片
        Column() {
          Text('综合评分')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ bottom: 8 });

          Text(`${overall}`)
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor(overall));

          Text(this.getScoreLevel(overall))
            .fontSize(16)
            .fontColor(this.getScoreColor(overall))
            .margin({ top: 4 });
        }
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 16 });

        // 三维度评分
        ForEach(Object.keys(dimNames), (key: string) => {
          const dim = dims[key] as Record<string, Object>;
          if (dim) {
            const score = dim.score as number;
            const comment = dim.comment as string;
            const suggestions = dim.suggestions as string[];

            Column() {
              // 维度名 + 分数
              Row() {
                Text(dimNames[key])
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333333');

                Text(`${score}`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getScoreColor(score));
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ bottom: 8 });

              // 评语
              Text(comment)
                .fontSize(14)
                .fontColor('#666666')
                .lineHeight(22)
                .width('100%')
                .margin({ bottom: 12 });

              // 建议列表
              if (suggestions && suggestions.length > 0) {
                Column() {
                  Text('改进建议')
                    .fontSize(13)
                    .fontColor('#FF9500')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 8 });

                  ForEach(suggestions, (sug: string) => {
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
                .backgroundColor('#FFF8E1')
                .borderRadius(8);
              }
            }
            .padding(16)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .width('100%')
            .margin({ bottom: 12 });
          }
        })

        // 综合评价
        if (r.summary) {
          Column() {
            Text('综合评价')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .margin({ bottom: 8 });

            Text(r.summary as string)
              .fontSize(14)
              .fontColor('#666666')
              .lineHeight(22);
          }
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .width('100%')
          .margin({ bottom: 16 });
        }

        // 再来一次按钮
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
}
