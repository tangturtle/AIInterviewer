@Entry
@Component
struct Report {
  build() {
    RelativeContainer() {
      Text('面试报告（开发中）')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .alignRules({
          center: { anchor: '__container__', align: VerticalAlign.Center },
          middle: { anchor: '__container__', align: HorizontalAlign.Center }
        })
    }
    .height('100%')
    .width('100%')
  }
}
