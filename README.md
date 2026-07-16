# AIInterviewer — AI 模拟面试官

> 基于真实 JD 的智能面试陪练 · 鸿蒙高校创新赛 · 应用创新赛道 参赛作品

AIInterviewer 是一款融合 AI 与鸿蒙能力的面试练习应用。粘贴真实岗位 JD，AI 自动生成针对性面试题；模拟面试中 AI 能根据你的回答智能追问；面试结束后生成三维度反馈报告，帮你快速提升面试能力。

---

## ✨ 功能特色

- **📋 JD 智能解析** — 粘贴岗位描述，AI 自动提取技能栈，按技术/行为/项目三类生成面试题
- **🤖 模拟面试 + 智能追问** — AI 逐题提问，根据你的回答动态追问（最多 3 轮），模拟真实面试节奏
- **📊 AI 三维度反馈** — 面试结束后，AI 从内容质量、表达逻辑、改进方向三个维度给出评分与建议
- **🔄 鸿蒙跨端协同** — 手机端完成面试，平板端查看深度复盘报告（基于分布式数据对象）

---

## 🛠 技术栈

| 层 | 技术 |
|----|------|
| 开发框架 | ArkUI + ArkTS |
| AI 能力 | LLM API（DeepSeek / 通义千问），流式输出 |
| 鸿蒙能力 | 分布式数据对象（`@ohos.data.distributedDataObject`）|
| 网络请求 | `@ohos.net.http` |
| 数据持久化 | Preferences |
| 构建工具 | DevEco Studio，SDK 6.1.1 |

---

## 🚀 快速开始

### 环境要求

- DevEco Studio（最新版）
- HarmonyOS SDK 6.1.1+
- LLM API Key（DeepSeek 或 通义千问）

### 运行步骤

```bash
# 1. 克隆项目
git clone https://github.com/tangturtle/AIInterviewer.git

# 2. 用 DevEco Studio 打开项目根目录

# 3. 等待依赖同步完成

# 4. 在 entry/src/main/ets/utils/config.ets 中配置 API Key

# 5. 选择模拟器或真机，点击运行
```

---

## 📁 项目结构

```
AIInterviewer/
├── entry/
│   └── src/main/ets/
│       ├── entryability/          # Ability 生命周期
│       ├── pages/                 # 页面
│       │   ├── Index.ets          # 面试前：JD 输入页
│       │   ├── Interview.ets      # 面试中：答题页
│       │   └── Report.ets         # 面试后：反馈报告页
│       └── utils/                 # 工具类
│           ├── http.ts            # HTTP 请求封装
│           └── prompt.ts          # LLM 提示词模板
├── AppScope/                      # 应用级配置
└── build-profile.json5            # 构建配置
```

---

## 🏗 鸿蒙能力体现

- **分布式数据对象** — 手机采集的面试数据实时同步到平板，实现多设备协作复盘
- **ArkUI 声明式 UI** — 多设备自适应布局，手机/平板一套代码
- **元服务可扩展** — 架构支持未来接入服务卡片，桌面直达面试入口

---

## 📄 许可证

本项目仅供学习交流使用。
