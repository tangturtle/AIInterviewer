# AIInterviewer Git 工作流规范

> 基于项目 AGENTS.md 约束，适用于 AI Agent 与开发者协作。

## 1. 分支策略

```
main        ─── 稳定发布版本，仅从 dev 合并
  ↑
dev         ─── 开发主分支，功能分支在此合并
  ↑
feature/xxx ─── 功能开发分支，从 dev 创建，完成后合回 dev
```

### 分支命名

| 分支类型 | 命名规范 | 示例 |
|---|---|---|
| 主分支 | `main` | 只接受 dev → main 的合并 |
| 开发分支 | `dev` | 日常开发集成分支 |
| 功能分支 | `feature/<简短描述>` | `feature/interview-page` |
| 修复分支 | `fix/<简短描述>` | `fix/http-auth-header` |
| 文档分支 | `docs/<简短描述>` | `docs/architecture-overview` |

## 2. 提交规范

### 2.1 提交前审核（强制）

**每次 `git commit` 和 `git push` 前必须：**

1. 向用户**逐条汇报**变更内容（改了哪些文件、改了哪些逻辑）
2. **等待用户明确批准**后才可执行
3. 若用户未回复或表示"等一下"，不得自动执行

### 2.2 安全检查（强制）

每次 `git commit` 和 `git push` 前必须检查：

- [ ] API Key、Token、密码等敏感信息未被 git 跟踪
- [ ] Preferences 存储的配置不会被提交
- [ ] `utils/` 目录中无实际密钥值硬编码
- [ ] `.gitignore` 覆盖了 `build/`、`.hvigor/`、`oh_modules/`、`local.properties`

### 2.3 提交信息格式

```
<type>: <简短描述>

<详细说明（可选，换行后写）>
```

**type 取值：**

| type | 说明 |
|---|---|
| `feat` | 新功能 |
| `fix` |  Bug 修复 |
| `docs` | 文档更新 |
| `refactor` | 代码重构（无功能变化） |
| `style` | 代码格式调整（lint、缩进等，非 CSS 样式） |
| `test` | 测试添加或修改 |
| `chore` | 构建、CI、依赖等杂项 |

### 2.4 示例

```
feat: 实现 JD 输入页面的基础 UI 和 API Key 配置

- 添加 JD 文本输入框和"开始面试"按钮
- 首次使用时弹出 API Key 配置弹窗
- 集成 PreferencesManager 持久化 Key
- 路由跳转到 Interview 页面

Closes #12
```

## 3. 工作流

### 3.1 日常开发流程

```bash
# 1. 确保在 dev 分支并最新
git checkout dev
git pull --rebase

# 2. 创建功能分支
git checkout -b feature/interview-page

# 3. 开发... 多次提交

# 4. 提交前：汇报变更 → 用户批准 → 提交
# （见第 2 节 提交前审核）

# 5. 保持与 dev 同步
git fetch origin
git rebase origin/dev

# 6. 推送并创建 PR（如适用）
git push origin feature/interview-page
```

### 3.2 合并原则

- 功能分支完成后，**在本地合入 dev** 进行集成测试
- 禁止直接向 `main` 推送代码（除非初始化）
- 多人协作时使用 PR + Code Review 流程

### 3.3 冲突处理

```bash
# 当前在 feature 分支
git fetch origin
git rebase origin/dev

# 解决冲突后
git add <resolved-files>
git rebase --continue
# 或 git rebase --abort 回退
```

## 4. .gitignore 覆盖范围

项目 `.gitignore` 必须包含：

```
# 构建产物
build/
.hvigor/
oh_modules/
local.properties

# IDE
.idea/
*.iml
.DS_Store

# 运行时
node_modules/
.hvigor_output/
```

## 5. AI Agent 专用规则

### 5.1 每次提交前必须执行的检查

1. **安全问题扫描**：`git diff --cached` 检查是否有 `apiKey`、`token`、`password`、`secret`、`[redacted]` 等敏感关键词
2. **占位符扫描**：检查是否有 `[redacted]`、`TODO`、`FIXME`、`TBD` 残留
3. **语法检查**：确认 `.ets` 文件无语法错误（通过 LSP diagnostics 验证）
4. **路由注册**：新增页面确保注册到 `main_pages.json`
5. **资源引用**：新增 `$r('app.xxx')` 确保对应资源已定义

### 5.2 禁止行为

- ❌ 禁止在未获用户批准的情况下执行 `git commit` 或 `git push`
- ❌ 禁止提交包含实际 API Key 的代码
- ❌ 禁止提交含 `[redacted]`、`TODO`、`FIXME` 等占位符的代码
- ❌ 禁止批量提交不相关的变更（一个 commit 只做一件事）

### 5.3 推荐行为

- ✅ 使用 `git add -p` 交互式暂存，精确控制每个 commit 的内容
- ✅ commit 信息简明扼要，描述变更的**意图**而非只写"做了什么"
- ✅ 大功能拆分为多个小 commit，方便回滚和 review
