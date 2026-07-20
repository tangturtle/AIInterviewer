# AIInterviewer ArkTS 编码规范

> 基于 HarmonyOS SDK 6.1.1、ArkTS 语言特性与项目约定。所有贡献者（含 AI Agent）必须遵守。

## 1. 语言规则

### 1.1 类型系统

- ✅ **必须**：所有变量和函数参数标注显式类型，禁止使用 `any`
- ✅ **必须**：优先使用 `string`、`number`、`boolean` 等基本类型联合
- ✅ **推荐**：复杂数据结构使用 `interface` 定义，使用 `?` 标注可选字段
- ❌ **禁止**：使用 `any`、`Function`、`object` 作为类型

```typescript
// ✅ 正确
function processJD(text: string): ParsedJD | null { ... }

// ❌ 错误
function processJD(text): any { ... }
```

### 1.2 空值处理

- ✅ **必须**：可空值使用 `T | null`，而非 `T | undefined`
- ✅ **必须**：访问可空值前进行 `null` 检查或使用 `?.` 可选链
- ✅ **必须**：async 函数返回 `Promise<T | null>` 表示可空

```typescript
// ✅ 正确
const key = await getApiKey(context);
if (key !== null) { /* 使用 key */ }

// ✅ 可选链
const val = obj?.nestedProp ?? defaultValue;
```

### 1.3 枚举与常量

- ✅ **推荐**：固定选项用 `enum` 或 `type union`
- ✅ **推荐**：业务常量使用 `const` 命名，`UPPER_SNAKE_CASE`

```typescript
// ✅ 类型联合
type QuestionType = 'technical' | 'behavioral' | 'project';
```

---

## 2. ArkUI 声明式规范

### 2.1 组件装饰器

- ✅ **必须**：Navigation 路由主机（`App.ets`）使用 `@Entry` + `@Component` 装饰
- ✅ **必须**：子页面仅使用 `@Component export struct` + `NavDestination()`，不再用 `@Entry`
- ✅ **必须**：复用组件仅使用 `@Component`
- ✅ **推荐**：组件内纯展示子组件用 `@Component` + `@Prop` / `@Link`

### 2.2 状态管理

| 装饰器 | 使用场景 |
|---|---|
| `@State` | 组件内部状态，页面级数据 |
| `@Prop` | 父 → 子单向传递 |
| `@Link` | 父子双向绑定（谨慎使用） |
| `@Provide` / `@Consume` | 跨层级祖先传递（业务复杂时再用） |
| `@StorageLink` | 应用级全局状态（暂不使用） |

- ✅ **必须**：`@State` 变量在 `struct` 中显式初始化
- ❌ **禁止**：`@State` 引用跨页面持久化（用 router params 传参）

```typescript
// ✅ 正确
@State jdText: string = '';
@State loading: boolean = false;

// ❌ 错误 — 缺少初始化
@State jdText: string;
```

### 2.3 布局与样式

- ✅ **推荐**：优先使用 `RelativeContainer` / `Flex` / `Column` / `Row` 进行布局
- ✅ **必须**：尺寸值使用 `vp`（`$r('app.float.xxx')`），避免硬编码 px
- ✅ **必须**：字符串资源使用 `$r('app.string.xxx')`
- ✅ **推荐**：颜色使用 `$r('app.color.xxx')` 引用资源文件
- ❌ **禁止**：在 `.ets` 中直接写中文字符串（统一放在 `string.json`）

### 2.4 事件处理

- ✅ **推荐**：复杂业务逻辑抽取为独立函数，不在 lambda 中写长逻辑
- ✅ **必须**：`async` 事件处理函数用 `.then()` 或 `try/catch` 包裹

```typescript
// ✅ 正确
build() {
  Button('开始面试')
    .onClick(() => this.startInterview());

  // ... 清理逻辑 inline
}

// ❌ 错误 — lambda 中写过长逻辑
.onClick(() => {
  // 50 行逻辑 ...
})
```

---

## 3. 文件与模块规范

### 3.1 文件命名

| 类型 | 规范 | 示例 |
|---|---|---|
| 页面 | `PascalCase.ets` | `Index.ets`, `Interview.ets` |
| 工具模块 | `camelCase.ets/.ts` | `http.ts`, `prompt.ts` |
| Ability | `PascalCase.ets` | `EntryAbility.ets` |
| 测试文件 | `PascalCase.test.ets` | `Ability.test.ets` |

### 3.2 导入顺序

按以下分组顺序排列，每组间空一行：

1. 系统 Kit（`@kit.*`）
2. 第三方 ohpm 包
3. 项目内部模块（`../utils/`、`../pages/`）

```typescript
import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';

import { saveApiKey, getApiKey } from '../utils/PreferencesManager';
```

### 3.3 模块职责

- **单一职责**：每个文件只做一件事。如果一个文件超过 200 行，考虑拆分
- **禁止循环依赖**：A → B → A 不允许
- **层间调用规则**：UI 层可调工具层，工具层不可调 UI 层

---

## 4. 日志规范

- ✅ **必须**：使用 `@kit.PerformanceAnalysisKit` 的 `hilog`
- ✅ **必须**：DOMAIN 统一使用 `0x0000`
- ✅ **必须**：tag 统一使用 `'AIInterviewer'`
- ✅ **必须**：用户数据用 `%{public}s`，敏感数据用 `%{private}s`

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';
const DOMAIN = 0x0000;
const TAG = 'AIInterviewer';

hilog.info(DOMAIN, TAG, 'JD parsed successfully: %{public}s', position);
hilog.debug(DOMAIN, TAG, 'API response: %{private}s', responseText);
```

> ✅ `EntryAbility.ets` 的 hilog tag 已从 `'testTag'` 统一为 `'AIInterviewer'`。

---

## 5. 安全规范

### 5.1 API Key

- ✅ **必须**：API Key 通过 Preferences 运行时配置，不硬编码
- ✅ **必须**：`utils/` 目录中禁止写入任何实际密钥值
- ✅ **必须**：Preferences 存储的配置不会被 git 跟踪
- ❌ **禁止**：在 `hilog` 中输出 API Key 内容

### 5.2 加密算法

- ❌ **禁止**：使用 MD5、3DES、RC4 等弱加密算法
- ✅ **推荐**：使用 HarmonyOS 安全 Kit 提供的强加密算法

### 5.3 输入校验

- ✅ **必须**：从 router params 接收的外部数据进行类型校验
- ✅ **必须**：用户输入的空格/换行进行 `.trim()` 处理

---

## 6. 注释规范

- ✅ **推荐**：导出函数添加 JSDoc 风格注释
- ✅ **必须**：复杂业务逻辑的关键步骤加注释说明意图
- ❌ **禁止**：保留无意义的注释（如 `// 设置值`）
- ❌ **禁止**：提交含有 `TODO`、`FIXME` 等占位符的代码

```typescript
/**
 * 解析 LLM 返回的 JD 结构化数据
 * @param response - LLM 原始 JSON 响应字符串
 * @returns 结构化 JD 数据，解析失败返回 null
 * @throws 不会抛出异常，解析失败返回 null
 */
export function parseJDResponse(response: string): ParsedJD | null { ... }
```

---

## 7. 测试规范

- ✅ **必须**：工具层函数编写 hypium 单元测试
- ✅ **推荐**：测试文件放在 `entry/src/ohosTest/ets/test/`
- ✅ **推荐**：使用 `describe` + `it` + `expect` 结构
- ✅ **必须**：mock 外部网络请求（不依赖真实 LLM API）

```typescript
describe('PreferencesManager', () => {
  it('should save and retrieve API key', 0, async () => {
    const context = getContext();
    await saveApiKey(context, 'test-key');
    const result = await getApiKey(context);
    expect(result).assertEqual('test-key');
  });
});
```

---

## 8. 编辑器配置

`.editorconfig` 配置（已内置在 DevEco Studio 中）：

```
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

---

## 9. Code Review Checklist

每次 PR 或 commit 前，逐条检查：

- [ ] 无 `any` 类型
- [ ] 无 `TODO`、`FIXME` 等占位符
- [ ] API Key 没有硬编码在代码中
- [ ] hilog 的 DOMAIN 为 `0x0000`，tag 为 `'AIInterviewer'`
- [ ] 字符串使用 `$r('app.string.xxx')`，中文不在 `.ets` 中硬编码
- [ ] 新增页面已注册到 `main_pages.json`
- [ ] 新增资源已在对应 `element/*.json` 中定义
- [ ] 无循环依赖（A → B → A）
- [ ] 导出函数有类型标注和 JSDoc 注释
- [ ] 文件不超过 200 行（超长考虑拆分）
