/**
 * AIInterviewer 共享类型定义
 *
 * 所有页面和 utils 模块共用此类型集。
 * 接口签名参考 docs/MODULE_INTERFACES.md 第 3 节。
 */

/** JD 文本经 LLM 解析后的结构化结果 */
export interface ParsedJD {
  position: string;           // 职位名称
  requirements: string[];     // 关键要求
  responsibilities: string[]; // 职责描述
  skills: string[];           // 技能关键词
}

/** 面试题目类型 */
export enum QuestionType {
  TECHNICAL = 'technical',
  BEHAVIORAL = 'behavioral',
  PROJECT = 'project'
}

/** 单道面试题 */
export interface InterviewQuestion {
  text: string;               // 题目正文
  type: QuestionType;         // 题目类型
  focusArea: string;          // 考察维度
}

/** 单轮追问记录 */
export interface FollowUpItem {
  question: string;
  answer: string;
}

/** 一轮问答（含追问） */
export interface QAPair {
  question: InterviewQuestion;
  answer: string;
  followUps: FollowUpItem[];
}

/** 评分维度枚举 */
export enum ScoreDimension {
  TECHNICAL = 'technical',
  EXPRESSION = 'expression',
  LOGIC = 'logic'
}

/** 某维度的评分详情 */
export interface DimensionScore {
  score: number;              // 分数（百分制）
  comment: string;            // 评语
  suggestions: string[];      // 改进建议列表
}

/** API 供应商信息 */
export interface ApiProvider {
  name: string;        // 唯一标识（如 'openai', 'deepseek'）
  label: string;       // 显示名称（如 'OpenAI', 'DeepSeek'）
  endpoint: string;    // API 端点 URL
}

/** LLM 返回的完整面试报告 */
export interface InterviewReport {
  overall: number;            // 总分（百分制）
  dimensions: {
    technical: DimensionScore;
    expression: DimensionScore;
    logic: DimensionScore;
  };
  summary: string;            // 综合评价
}
