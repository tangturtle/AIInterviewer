# AIInterviewer | AI 模拟面试官

> 基于真实 JD 的智能面试陪练 · 鸿蒙高校创新赛 · 应用创新赛道 参赛作品

粘贴一份岗位 JD，得到按技术、行为、项目三类拆解的面试题。答题时，每个回答触发最多三轮追问，模拟真实面试官的追问节奏。结束后拿到内容质量、表达逻辑、改进方向三个维度的反馈。

---

## 功能

**JD 解析**：粘贴岗位描述，拆出技能栈，按技术、行为、项目三类生成面试题。

**模拟面试与追问**：逐题提问。每个回答触发最多三轮追问。追问方向和深度取决于你回答的内容。

**三维度反馈**：面试结束后给出内容质量、表达逻辑、改进方向三个维度的评分和建议。

**跨端协同**：手机面试，平板复盘。面试数据通过鸿蒙分布式数据对象在设备间流转。

---

## 技术栈

| 层     | 技术                                          |
|-------|---------------------------------------------|
| 开发框架  | ArkUI + ArkTS                               |
| AI 能力 | LLM API（DeepSeek / 通义千问），流式输出               |
| 鸿蒙能力  | 分布式数据对象（`@ohos.data.distributedDataObject`） |
| 网络请求  | `@ohos.net.http`                            |
| 数据持久化 | Preferences                                 |
| 构建工具  | DevEco Studio，SDK 6.1.1                     |

---

## 快速开始

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

# 4. 首次启动：在应用设置页面输入 API Key（Preferences 持久化存储，仅存本地）

# 5. 选择模拟器或真机，点击运行
```

---

## 项目结构

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
│           ├── PreferencesManager.ets  # API Key 持久化存储
│           └── http.ts            # HTTP 请求封装
├── AppScope/                      # 应用级配置
└── build-profile.json5            # 构建配置
```

---

## 鸿蒙能力

**分布式数据对象**：面试数据在手机和平板之间实时同步，无需手动传输。

**ArkUI 声明式 UI**：同一套代码适配手机和平板两种布局。

**元服务**：架构预留了服务卡片接入点，可以从桌面直达面试入口。

---

## 许可证

本项目仅供学习交流使用。
