import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'AIInterviewer', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AIInterviewer', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'Succeeded in loading the content.');
    });

    // ── Phase 1 端到端验证：LLM 完整链路 ──────────────────
    // 验证 prompt.ts 各模块是否可正确协同工作
    // 通过 Preferences 获取 API Key，在 APP 运行后调用
    this.runE2ETest();
  }

  /**
   * Phase 1 端到端验证：测试整个 LLM 调用链路
   *
   * 流程：JD 解析 → 首轮面试题 → 追问 → 评分报告
   * 所有步骤结果通过 hilog.info 输出，可在 DevEco Studio Log 面板查看
   */
  private async runE2ETest(): Promise<void> {
    try {
      const { getApiKey } = require('../utils/PreferencesManager');
      const apiKey = await getApiKey(this.context);
      if (!apiKey) {
        hilog.info(DOMAIN, 'AIInterviewer', 'E2E: 跳过 — 未配置 API Key');
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E: API Key 已配置，开始链路测试');

      // Step 1: JD 解析
      const testJD = `岗位：前端开发工程师
要求：精通 HTML/CSS/JavaScript，熟悉 React 或 Vue 框架，3 年以上工作经验
职责：负责 Web 应用的前端架构设计和核心功能开发`;

      const { buildJDPrompt, parseJDResponse, callLLM,
              buildQuestionPrompt, parseQuestionResponse,
              buildFollowUpPrompt, buildReportPrompt, parseReportResponse } =
        require('../utils/prompt');

      const jdPrompt = buildJDPrompt(testJD);
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step1: 发送 JD 解析请求');
      const jdRaw = await callLLM(apiKey, '你是一个专业的职位解析助手。', jdPrompt);
      const parsedJD = parseJDResponse(jdRaw);
      if (!parsedJD) {
        hilog.error(DOMAIN, 'AIInterviewer', 'E2E Step1: JD 解析失败');
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step1: JD 解析成功 — %{public}s', JSON.stringify(parsedJD));

      // Step 2: 生成首轮面试题
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step2: 生成首轮面试题');
      const qPrompt = buildQuestionPrompt(parsedJD, 1);
      const qRaw = await callLLM(apiKey, '你是一个专业的面试官。', qPrompt);
      const question = parseQuestionResponse(qRaw);
      if (!question) {
        hilog.error(DOMAIN, 'AIInterviewer', 'E2E Step2: 题目解析失败');
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step2: 题目生成成功 — %{public}s', JSON.stringify(question));

      // Step 3: 模拟回答 + 追问
      const mockAnswer = '这是我的回答。';
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step3: 发送追问请求');
      const followUpPrompt = buildFollowUpPrompt(question, mockAnswer, []);
      const followUpRaw = await callLLM(apiKey, '你是一个专业的面试官。', followUpPrompt);
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step3: 追问结果 — %{public}s', followUpRaw);

      // Step 4: 生成评分报告
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step4: 生成评分报告');
      const reportPrompt = buildReportPrompt(
        [{ question, answer: mockAnswer, followUps: [] }],
        parsedJD
      );
      const reportRaw = await callLLM(apiKey, '你是一个专业的面试评估专家。', reportPrompt);
      const report = parseReportResponse(reportRaw);
      if (!report) {
        hilog.error(DOMAIN, 'AIInterviewer', 'E2E Step4: 报告解析失败');
        return;
      }
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E Step4: 报告生成成功 — overall=%{public}d', report.overall);
      hilog.info(DOMAIN, 'AIInterviewer', 'E2E: 链路测试全部通过');
    } catch (err) {
      hilog.error(DOMAIN, 'AIInterviewer', 'E2E: 链路测试异常 — %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'AIInterviewer', '%{public}s', 'Ability onBackground');
  }
}
