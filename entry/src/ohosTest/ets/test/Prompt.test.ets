/**
 * AIInterviewer Prompt 模块单元测试
 *
 * 测试策略：
 * - build* 函数：验证返回非空字符串且包含关键字段
 * - parse* 函数：正常 JSON → 正确解析；非法输入 → 返回 null
 * - callLLM：需要真实网络，暂不测试（由端到端验证覆盖）
 */
import { describe, it, expect } from '@ohos/hypium';
import {
  buildJDPrompt,
  parseJDResponse,
  buildQuestionPrompt,
  parseQuestionResponse,
  buildFollowUpPrompt,
  buildReportPrompt,
  parseReportResponse,
  callLLM
} from '../../../../../../../entry/src/main/ets/utils/prompt';
import type {
  ParsedJD, InterviewQuestion, QAPair
} from '../../../../../../../entry/src/main/ets/utils/types';

// ── 模拟数据 ──────────────────────────────────────────────

const mockJD: ParsedJD = {
  position: '高级前端工程师',
  requirements: ['精通 TypeScript', '5 年以上前端经验'],
  responsibilities: ['负责核心模块架构设计'],
  skills: ['React', 'TypeScript', 'Webpack']
};

const mockQuestion: InterviewQuestion = {
  text: '请解释 React 的 Fiber 架构',
  type: 'technical',
  focusArea: '对 React 核心原理的理解'
};

const mockQAPairs: QAPair[] = [
  {
    question: mockQuestion,
    answer: 'Fiber 是 React 16 引入的协调引擎...',
    followUps: [
      { question: '那 Fiber 和 Stack 对比有什么优势？', answer: 'Fiber 是可中断的...' }
    ]
  }
];

// ── 模拟 LLM 响应 JSON ────────────────────────────────────

const mockLLMResponse = (content: string): string => {
  return JSON.stringify({
    id: 'chatcmpl-mock',
    choices: [
      {
        index: 0,
        message: { role: 'assistant', content }
      }
    ]
  });
};

const mockJDResponse = mockLLMResponse(JSON.stringify({
  position: '高级前端工程师',
  requirements: ['精通 TypeScript', '5 年以上前端经验'],
  responsibilities: ['负责核心模块架构设计'],
  skills: ['React', 'TypeScript', 'Webpack']
}));

const mockQuestionResponse = mockLLMResponse(JSON.stringify({
  text: '请解释 React 的 Fiber 架构',
  type: 'technical',
  focusArea: '对 React 核心原理的理解'
}));

const mockReportResponse = mockLLMResponse(JSON.stringify({
  overall: 82,
  dimensions: {
    technical: { score: 78, comment: '基础扎实', suggestions: ['深入学习底层原理'] },
    expression: { score: 85, comment: '表达清晰', suggestions: ['增加具体案例'] },
    logic: { score: 80, comment: '逻辑性强', suggestions: ['加强结构组织'] }
  },
  summary: '整体表现良好'
}));

// ── 测试套件 ──────────────────────────────────────────────

export default function promptTest() {
  describe('promptTest', () => {

    // ── build* 函数 ────────────────────────────────────

    it('buildJDPrompt_返回非空字符串包含关键字段', 0, () => {
      const prompt = buildJDPrompt('招聘 Java 后端工程师...');
      expect(prompt).not().assertNull();
      expect(prompt.length).assertGreaterThan(50);
      expect(prompt).assertContain('position');
      expect(prompt).assertContain('requirements');
      expect(prompt).assertContain('skills');
    });

    it('buildQuestionPrompt_包含职位信息和轮次描述', 0, () => {
      const prompt = buildQuestionPrompt(mockJD, 1);
      expect(prompt).not().assertNull();
      expect(prompt).assertContain('高级前端工程师');
      expect(prompt).assertContain('TypeScript');
      expect(prompt).assertContain('JSON');
      expect(prompt).assertContain('text');
      expect(prompt).assertContain('type');
    });

    it('buildQuestionPrompt_轮次3使用行为描述', 0, () => {
      const prompt = buildQuestionPrompt(mockJD, 3);
      expect(prompt).assertContain('行为');
    });

    it('buildFollowUpPrompt_包含原题和回答上下文', 0, () => {
      const prompt = buildFollowUpPrompt(mockQuestion, '这是一个测试回答', mockQAPairs);
      expect(prompt).not().assertNull();
      expect(prompt).assertContain('Fiber');
      expect(prompt).assertContain('测试回答');
    });

    it('buildFollowUpPrompt_空历史也能正常返回', 0, () => {
      const prompt = buildFollowUpPrompt(mockQuestion, '回答内容', []);
      expect(prompt).not().assertNull();
      expect(prompt).assertContain('回答内容');
    });

    it('buildReportPrompt_包含对话记录和评分维度', 0, () => {
      const prompt = buildReportPrompt(mockQAPairs, mockJD);
      expect(prompt).not().assertNull();
      expect(prompt).assertContain('technical');
      expect(prompt).assertContain('expression');
      expect(prompt).assertContain('logic');
      expect(prompt).assertContain('overall');
    });

    // ── parse* 函数 — 正常路径 ──────────────────────────

    it('parseJDResponse_正常返回解析成功', 0, () => {
      const result = parseJDResponse(mockJDResponse);
      expect(result).not().assertNull();
      if (result) {
        expect(result.position).assertEqual('高级前端工程师');
        expect(result.skills.length).assertEqual(3);
      }
    });

    it('parseQuestionResponse_正常返回解析成功', 0, () => {
      const result = parseQuestionResponse(mockQuestionResponse);
      expect(result).not().assertNull();
      if (result) {
        expect(result.text).assertContain('Fiber');
        expect(result.type).assertEqual('technical');
      }
    });

    it('parseReportResponse_正常返回解析成功', 0, () => {
      const result = parseReportResponse(mockReportResponse);
      expect(result).not().assertNull();
      if (result) {
        expect(result.overall).assertEqual(82);
        expect(result.dimensions.technical.score).assertEqual(78);
        expect(result.dimensions.expression.suggestions.length).assertGreaterThan(0);
      }
    });

    // ── parse* 函数 — 异常路径 ──────────────────────────

    it('parseJDResponse_空字符串返回null', 0, () => {
      const result = parseJDResponse(mockLLMResponse(''));
      expect(result).assertNull();
    });

    it('parseJDResponse_非法JSON返回null', 0, () => {
      const result = parseJDResponse(mockLLMResponse('这不是 JSON'));
      expect(result).assertNull();
    });

    it('parseJDResponse_choices为空返回null', 0, () => {
      const result = parseJDResponse(JSON.stringify({ choices: [] }));
      expect(result).assertNull();
    });

    it('parseQuestionResponse_非法JSON返回null', 0, () => {
      const result = parseQuestionResponse('不是 JSON');
      expect(result).assertNull();
    });

    it('parseQuestionResponse_缺少字段返回null', 0, () => {
      const resp = mockLLMResponse(JSON.stringify({ text: '仅有文本' }));
      const result = parseQuestionResponse(resp);
      expect(result).assertNull();
    });

    it('parseReportResponse_分数越界自动修正', 0, () => {
      const badReport = mockLLMResponse(JSON.stringify({
        overall: 150,
        dimensions: {
          technical: { score: -10, comment: 'test', suggestions: [] },
          expression: { score: 50, comment: 'test', suggestions: [] },
          logic: { score: 50, comment: 'test', suggestions: [] }
        },
        summary: 'test'
      }));
      const result = parseReportResponse(badReport);
      expect(result).not().assertNull();
      if (result) {
        expect(result.overall).assertEqual(100);
        expect(result.dimensions.technical.score).assertEqual(0);
      }
    });

    it('parseReportResponse_缺少维度返回null', 0, () => {
      const bad = mockLLMResponse(JSON.stringify({ overall: 80, summary: 'test' }));
      const result = parseReportResponse(bad);
      expect(result).assertNull();
    });

    // ── 代码块格式支持 ──────────────────────────────────

    it('parseJDResponse_支持markdown代码块格式', 0, () => {
      const content = '```json\n{"position": "后端开发", "requirements": ["Go"], "responsibilities": ["开发"], "skills": ["Go"]}\n```';
      const resp = mockLLMResponse(content);
      const result = parseJDResponse(resp);
      expect(result).not().assertNull();
      if (result) {
        expect(result.position).assertEqual('后端开发');
      }
    });

    // ── Module 级验证 ──────────────────────────────────

    it('模块导出函数列表完整', 0, () => {
      expect(typeof buildJDPrompt).assertEqual('function');
      expect(typeof parseJDResponse).assertEqual('function');
      expect(typeof buildQuestionPrompt).assertEqual('function');
      expect(typeof parseQuestionResponse).assertEqual('function');
      expect(typeof buildFollowUpPrompt).assertEqual('function');
      expect(typeof buildReportPrompt).assertEqual('function');
      expect(typeof parseReportResponse).assertEqual('function');
      expect(typeof callLLM).assertEqual('function');
    });
  });
}
