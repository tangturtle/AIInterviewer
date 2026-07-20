/**
 * AIInterviewer 提示词工程模块
 *
 * 管理所有 LLM prompt 模板和 JSON 响应解析逻辑。
 * 所有 prompt 使用中文编写，要求 LLM 返回严格 JSON 格式。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { post, streamPost, StreamCallbacks } from './http';
import type {
  ParsedJD, InterviewQuestion, QAPair, InterviewReport
} from './types';

// ── 默认 LLM 端点 ──────────────────────────────────────────

/** 默认 LLM API 端点（Provider 配置后通过 Preferences 覆盖） */
export const DEFAULT_ENDPOINT = 'https://api.deepseek.com/chat/completions';

/** 默认模型名 */
export const DEFAULT_MODEL = 'deepseek-v4-flash';

// ── 内部辅助：LLM 调用封装 ─────────────────────────────────

/**
 * 调用 LLM API，返回原始响应字符串
 * @param apiKey - API Key
 * @param systemPrompt - 系统级提示词
 * @param userPrompt - 用户级提示词
 * @param endpoint - LLM API 端点（可选，默认 DEFAULT_ENDPOINT）
 * @returns LLM 返回的原始 JSON 字符串
 * @throws 网络错误或非 2xx 状态码
 */
export async function callLLM(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string,
  endpoint: string = DEFAULT_ENDPOINT,
  model: string = DEFAULT_MODEL
): Promise<string> {
  const body = {
    model: model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
    temperature: 0.7
  };
  return await post(endpoint, body, apiKey);
}

/**
 * 流式调用 LLM API
 * @param apiKey - API Key
 * @param systemPrompt - 系统级提示词
 * @param userPrompt - 用户级提示词
 * @param callbacks - 流式回调（onContent / onReasoning）
 * @param endpoint - LLM API 端点（可选）
 * @param model - 模型名（可选）
 * @returns 包含 request(取消句柄) 和 result(完整文本 Promise) 的对象
 */
export function callLLMStream(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string,
  callbacks: {
    onContent: (fullText: string) => void;
    onReasoning?: (text: string) => void;
  },
  endpoint: string = DEFAULT_ENDPOINT,
  model: string = DEFAULT_MODEL
): { request: http.HttpRequest; result: Promise<string> } {
  let fullText = '';
  let resolvePromise: (text: string) => void = () => {};
  let rejectPromise: (err: Error) => void = () => {};

  const result = new Promise<string>((resolve: (text: string) => void, reject: (err: Error) => void) => {
    resolvePromise = resolve;
    rejectPromise = reject;
  });

  const streamCallbacks: StreamCallbacks = {
    onContent: (delta: string): void => {
      fullText += delta;
      callbacks.onContent(fullText);
    },
    onReasoning: (text: string): void => {
      callbacks.onReasoning?.(text);
    },
    onError: (err: Error): void => {
      rejectPromise(err);
    },
    onDone: (): void => {
      resolvePromise(fullText);
    }
  };

  const body = {
    model: model,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ],
    temperature: 0.7
  };

  const request = streamPost(endpoint, body, apiKey, streamCallbacks);
  return { request, result };
}

/**
 * 将流式累积的 content 重新包裹为 LLM 响应结构，
 * 供现有 parse*Response() 函数复用
 * @param content - 流式累积的 choices[0].delta.content 完整文本
 * @returns 兼容 LLM API 响应的 JSON 字符串
 */
export function reconstructResponse(content: string): string {
  return JSON.stringify({
    choices: [{ message: { content: content } }]
  });
}

// ── Prompt 构建函数 ────────────────────────────────────────

/**
 * 构建 JD 解析 prompt
 * @param jdText - 用户粘贴的 JD 文本
 * @returns 组装好的 user prompt 字符串
 */
export function buildJDPrompt(jdText: string): string {
  return `请从以下职位描述中提取结构化信息，只返回 JSON，不要包含其他文字。

职位描述：
"""
${jdText}
"""

请返回如下 JSON 格式（必须严格遵循）：
{
  "position": "职位名称",
  "requirements": ["关键要求1", "关键要求2", ...],
  "responsibilities": ["职责描述1", "职责描述2", ...],
  "skills": ["技能关键词1", "技能关键词2", ...]
}`;
}

/**
 * 构建面试题生成 prompt
 * @param jd - 已解析的 JD 结构化数据
 * @param round - 轮次（1=技术基础，2=项目深度，3=行为/综合）
 * @returns 组装好的 user prompt 字符串
 */
export function buildQuestionPrompt(jd: ParsedJD, round: number): string {
  const roundDescriptions: Record<number, string> = {
    1: '第一轮（技术基础）：围绕 JD 中的技能关键词，考察候选人的技术基础掌握程度。',
    2: '第二轮（项目深度）：基于 JD 的职责描述和经验要求，深入考察候选人过往项目经验和解决问题能力。',
    3: '第三轮（行为/综合）：考察候选人的综合素质、团队协作、职业规划等行为面试问题。'
  };
  const desc = roundDescriptions[round] || roundDescriptions[1];

  return `你是一名专业的面试官，正在面试以下职位。

职位信息：
- 职位名称：${jd.position}
- 关键要求：${jd.requirements.join('、')}
- 职责描述：${jd.responsibilities.join('、')}
- 技能关键词：${jd.skills.join('、')}

${desc}

请只返回一道面试题，格式为严格 JSON，不要包含其他文字：
{
  "text": "面试题目正文",
  "type": "technical" | "behavioral" | "project",
  "focusArea": "本题重点考察的维度描述"
}`;
}

/**
 * 构建追问 prompt
 * @param question - 原面试题
 * @param answer - 用户的回答
 * @param history - 历史问答记录（用于多轮上下文拼接）
 * @returns 组装好的 user prompt 字符串
 */
export function buildFollowUpPrompt(
  question: InterviewQuestion,
  answer: string,
  history: QAPair[]
): string {
  const contextLines = history.flatMap((qa, i) => {
    const lines = [`原题 ${i + 1}: ${qa.question.text}`];
    lines.push(`用户回答 ${i + 1}: ${qa.answer}`);
    qa.followUps.forEach((fu, j) => {
      lines.push(`追问 ${i + 1}-${j + 1}: ${fu.question}`);
      lines.push(`用户回答 ${i + 1}-${j + 1}: ${fu.answer}`);
    });
    return lines;
  }).join('\n');

  return `你是一名专业的面试官。以下是当前面试场景：

当前题目：${question.text}
题目类型：${question.type}
考察维度：${question.focusArea}

用户回答：${answer}

${
  history.length > 0
    ? `历史问答记录：\n${contextLines}\n`
    : ''
}

请根据用户的回答生成一个有针对性的追问。追问应该：
1. 深入挖掘用户回答中提到的具体内容
2. 考察用户的知识深度和思考过程
3. 不要重复原题，而是在已有回答基础上深入

请只返回追问文本本身，不要包含其他文字，不要使用 JSON 格式。`;
}

/**
 * 构建评分报告 prompt
 * @param qaHistory - 完整的问答历史
 * @param jd - JD 结构化数据
 * @returns 组装好的 user prompt 字符串
 */
export function buildReportPrompt(qaHistory: QAPair[], jd: ParsedJD): string {
  const conversationLines = qaHistory.flatMap((qa, i) => {
    const lines = [`【第 ${i + 1} 题】${qa.question.text}`];
    lines.push(`用户回答：${qa.answer}`);
    qa.followUps.forEach((fu, j) => {
      lines.push(`追问：${fu.question}`);
      lines.push(`用户回答：${fu.answer}`);
    });
    return lines;
  }).join('\n');

  return `你是一名专业的面试评估专家。请基于以下面试对话记录，对候选人进行三维度评分。

招聘职位：${jd.position}
职位要求：${jd.requirements.join('、')}
所需技能：${jd.skills.join('、')}

面试对话记录：
${conversationLines}

请从以下三个维度评分（百分制），只返回 JSON，不要包含其他文字：
{
  "overall": 75,
  "dimensions": {
    "technical": {
      "score": 70,
      "comment": "技术能力评语",
      "suggestions": ["建议1", "建议2"]
    },
    "expression": {
      "score": 70,
      "comment": "表达沟通评语",
      "suggestions": ["建议1", "建议2"]
    },
    "logic": {
      "score": 70,
      "comment": "逻辑思维评语",
      "suggestions": ["建议1", "建议2"]
    }
  },
  "summary": "综合评价"
}

评分标准：
- technical（技术深度）：技能掌握程度、知识体系完整性、对技术原理的理解
- expression（表达沟通）：回答条理性、语言流畅度、重点突出程度
- logic（逻辑思维）：因果推理能力、分析深度、回答结构

分数区间：
- 90-100：优秀
- 75-89：良好
- 60-74：一般
- 0-59：需要加强`;
}

// ── 响应解析函数 ───────────────────────────────────────────

/**
 * 从 LLM 原始响应中提取 JSON 字符串
 * @param response - LLM API 返回的完整响应 JSON 字符串
 * @returns 提取出的 JSON 字符串，提取失败返回 null
 */
function extractContent(response: string): string | null {
  try {
    const parsed = JSON.parse(response);
    const content: string | undefined = parsed?.choices?.[0]?.message?.content;
    if (!content || content.length === 0) {
      return null;
    }
    return content;
  } catch (err) {
    hilog.error(0x0000, 'AIInterviewer', 'extractContent: failed to parse LLM response: %{public}s', err instanceof Error ? err.message : JSON.stringify(err));
    return null;
  }
}

/**
 * 解析 LLM 返回的 JD 结构化数据
 * @param response - LLM API 原始响应字符串
 * @returns 结构化 JD 数据，解析失败返回 null
 */
export function parseJDResponse(response: string): ParsedJD | null {
  try {
    const content = extractContent(response);
    if (!content) {
      return null;
    }
    // 尝试从代码块中提取 JSON
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    const jsonStr = jsonMatch ? jsonMatch[1].trim() : content.trim();
    const data = JSON.parse(jsonStr);
    if (
      typeof data.position === 'string' &&
      Array.isArray(data.requirements) &&
      Array.isArray(data.responsibilities) &&
      Array.isArray(data.skills)
    ) {
      return {
        position: data.position,
        requirements: data.requirements.map(String),
        responsibilities: data.responsibilities.map(String),
        skills: data.skills.map(String)
      };
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * 解析 LLM 返回的面试题
 * @param response - LLM API 原始响应字符串
 * @returns 解析后的面试题，解析失败返回 null
 */
export function parseQuestionResponse(response: string): InterviewQuestion | null {
  try {
    const content = extractContent(response);
    if (!content) {
      return null;
    }
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    const jsonStr = jsonMatch ? jsonMatch[1].trim() : content.trim();
    const data = JSON.parse(jsonStr);
    const validTypes = ['technical', 'behavioral', 'project'];
    if (
      typeof data.text === 'string' &&
      typeof data.type === 'string' &&
      validTypes.includes(data.type) &&
      typeof data.focusArea === 'string'
    ) {
      return {
        text: data.text,
        type: data.type as InterviewQuestion['type'],
        focusArea: data.focusArea
      };
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * 解析 LLM 返回的追问文本
 *
 * 追问 prompt 要求 LLM 返回纯文本（非 JSON），但 API 仍会包裹在
 * JSON 信封中。本函数从中提取 choices[0].message.content 字段。
 * @param response - LLM API 原始响应字符串
 * @returns 追问文本，解析失败返回 null
 */
export function parseFollowUpResponse(response: string): string | null {
  return extractContent(response);
}

/**
 * 解析 LLM 返回的评分报告
 * @param response - LLM API 原始响应字符串
 * @returns 解析后的评分报告，解析失败返回 null
 */
export function parseReportResponse(response: string): InterviewReport | null {
  try {
    const content = extractContent(response);
    if (!content) {
      return null;
    }
    const jsonMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
    const jsonStr = jsonMatch ? jsonMatch[1].trim() : content.trim();
    const data = JSON.parse(jsonStr);

    if (
      typeof data.overall !== 'number' ||
      !data.dimensions ||
      typeof data.dimensions.technical !== 'object' ||
      typeof data.dimensions.expression !== 'object' ||
      typeof data.dimensions.logic !== 'object' ||
      typeof data.summary !== 'string'
    ) {
      return null;
    }

    const dims = data.dimensions;
    const validateDim = (d: Record<string, Object>): boolean =>
      typeof d.score === 'number' &&
      d.score >= 0 && d.score <= 100 &&
      typeof d.comment === 'string' &&
      Array.isArray(d.suggestions);

    if (
      !validateDim(dims.technical) ||
      !validateDim(dims.expression) ||
      !validateDim(dims.logic)
    ) {
      return null;
    }

    const clampScore = (score: number): number =>
      Math.max(0, Math.min(100, Math.round(score)));

    return {
      overall: clampScore(data.overall),
      dimensions: {
        technical: {
          score: clampScore(dims.technical.score),
          comment: dims.technical.comment,
          suggestions: dims.technical.suggestions.map(String)
        },
        expression: {
          score: clampScore(dims.expression.score),
          comment: dims.expression.comment,
          suggestions: dims.expression.suggestions.map(String)
        },
        logic: {
          score: clampScore(dims.logic.score),
          comment: dims.logic.comment,
          suggestions: dims.logic.suggestions.map(String)
        }
      },
      summary: data.summary
    };
  } catch {
    return null;
  }
}
