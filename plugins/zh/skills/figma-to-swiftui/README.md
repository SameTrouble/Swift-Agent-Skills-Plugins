# Figma 到 SwiftUI 技能

使用 [Figma MCP Server](https://developers.figma.com/docs/figma-mcp-server/) 将 Figma 设计转换为像素级精准的生产级 SwiftUI 代码。基于 [Agent Skills 开放格式](https://agentskills.io/home) 构建。

此技能提供结构化的工作流，引导 AI 代理完成源文档审查、元数据优先的屏幕发现、设计上下文获取、PNG 资源导出、视觉保真度检查和原生 SwiftUI 实现——而非盲目移植 React + Tailwind 输出。

## 适用人群

* 在 Figma 中收到设计并希望加速实现的 iOS 开发者
* 使用 Figma Dev Mode 并希望一致的设计到代码转换的团队
* 希望 AI 编码工具生成原生 SwiftUI 而非 Web 风格布局的任何人

## 此技能的功能

### 结构化工作流

引导代理完成源文档审查、URL 解析、元数据优先的屏幕发现、设计上下文获取、截图捕获、令牌映射、资源清单/下载、SwiftUI 实现、可选验证和 Code Connect 注册。

### 源文档优先

当与 Figma 工作一起提供 `.txt`、`.md`、工单、PM 需求文档或内联规格说明时，技能在任何 Figma MCP 调用之前阅读它。文档定义范围、操作、异步工作、必需状态和范围外项；Figma 在该范围内保持视觉真实依据的地位。

### 元数据优先的屏幕发现

对于根节点、页面节点、大型容器或模糊的多屏幕画板，技能在 `get_design_context` 之前运行 `get_metadata`。它构建带有置信度的候选屏幕映射，而非盲目获取大型节点。

### 原生 SwiftUI 翻译

完整的映射表：
* **布局** —— Figma Auto Layout → VStack/HStack/ZStack、padding、spacing、尺寸模式
* **排版** —— font family、weight、size、line height、letter spacing
* **颜色** —— hex、渐变、不透明度、深色模式、设计令牌
* **组件** —— 按钮、输入框、列表、导航、sheet、卡片
* **效果** —— 阴影、模糊、圆角、边框、遮罩、Liquid Glass（iOS 26+）
* **动画** —— 原型过渡 → SwiftUI 动画、匹配几何、Lottie 集成

### 智能资源处理

* 优先使用 Figma 资源——不对 Figma 设计的图标、Logo 或插画进行 SF Symbol 替换
* 默认将可见的 Figma 拥有资源导出为 Figma 渲染的 PNG
* 将 SVG/XML/文本响应视为导出失败，并通过 `get_screenshot` 重新获取
* 在 SwiftUI 实现之前构建视觉资源清单
* 将 PNG 资源添加到 Asset Catalog，包含 @1x/@2x/@3x 变体和正确的渲染模式

### 项目感知

* 在实现之前检查项目依赖——使用 Kingfisher、Lottie、SnapKit 或项目已有的任何库，而非引入原生替代方案
* 将 Figma 设计令牌映射到项目现有的颜色/排版/间距系统
* 跳过系统提供的元素（键盘、状态栏、主指示条、系统提醒等）
* 尊重平台约定：安全区域、动态字号、无障碍

### 不对架构持有偏见

此技能仅处理视觉翻译。它不强制 MV、MVVM 或任何其他模式——那是你的架构技能的工作。

## 如何使用此技能

### 快速安装

```bash
npx skills add https://github.com/daetojemax/figma-to-swiftui-skill --skill figma-to-swiftui
```

### 手动安装

1. **克隆**此仓库
2. 按照你的工具的技能安装文档**安装或符号链接**此仓库文件夹
3. **确保 Figma MCP 服务器已连接**——排障参见 `references/figma-mcp-setup.md`

然后在你的 AI 代理中使用：

> Use the figma-to-swiftui skill and implement this design: https://www.figma.com/design/abc123/MyApp?node-id=10-5&m=dev

附带需求文档：

> Use the figma-to-swiftui skill. Implement this Login screen from Figma: https://www.figma.com/design/abc123/MyApp?node-id=10-5&m=dev. Also read this brief first: Sign In validates email/password, disables the CTA until valid, shows loading while submitting, shows inline auth errors, and navigates to Profile on success. Signup and reset password are out of scope.

#### 技能保存位置

* **Codex：** [Where to save skills](https://developers.openai.com/codex/skills/#where-to-save-skills)
* **Claude Code：** [Using Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#using-skills)
* **Cursor：** [Enabling Skills](https://cursor.com/docs/context/skills#enabling-skills)

## 前置条件

* **Figma MCP 服务器**已连接并认证（参见 `references/figma-mcp-setup.md`）
* 带有节点 ID 的 **Figma URL** —— 支持 `/design/` 和旧版 `/file/` 格式，带或不带 `www.`、`&m=dev` 等
* 带有成熟 SwiftUI 代码库的 **Xcode 项目**（推荐）
* 可选的**源文档**（`.txt`、`.md`、工单、PM 需求文档或内联规格说明），描述范围、操作、状态和约束

## 技能结构

```
figma-to-swiftui-skill/
  SKILL.md                                — 主工作流
  references/
    source-document.md                    — 在 Figma 之前阅读 .txt/.md/规格；范围和行为契约
    screen-discovery.md                   — 根/页面/多屏幕节点的元数据优先映射
    fetch-strategy.md                     — 超时安全的元数据/上下文策略和去重规则
    visual-fidelity.md                    — 精确值提取、视觉清单、SwiftUI 陷阱
    layout-translation.md                 — Auto Layout → Stacks、尺寸、滚动、常见模式
    responsive-layout.md                  — 尺寸类别、自适应布局、多设备设计
    design-token-mapping.md               — Figma 变量 → Color/Font/Spacing 令牌
    component-variants.md                 — Figma 变体 → SwiftUI 样式和枚举
    asset-handling.md                      — Figma 渲染的 PNG 资源、xcassets、远程图像
    adaptation-workflow.md                — 现有屏幕适配和差异审计
    figma-mcp-setup.md                    — MCP 连接、排障
```

## 关键设计决策

**MCP 输出是规范，不是代码。** Figma MCP 默认返回 React + Tailwind。此技能将其视为设计规范，从提取的属性构建原生 SwiftUI——绝不移植 Web 代码。

**源文档定义范围和行为。** 如果提供了需求文档或工单，它在 Figma 之前被阅读。文档决定屏幕、操作、异步行为、必需状态和范围外工作；Figma 决定视觉效果。

**元数据先于昂贵的上下文获取。** 根/页面/多屏幕节点在 `get_design_context` 之前用 `get_metadata` 检查，使代理不会盲目获取整个 Figma 页面。

**Figma 资源优先。** 可见的 Figma 拥有资源导出为 PNG 并添加到 Asset Catalog。SF Symbols 仅用于系统组件或用户批准的替换。

**询问，而非假设。** 技能提示用户做出它无法安全做出的决定：验证方法、模糊的屏幕/操作映射、未找到图像加载库时、元素是系统提供还是自定义。

**系统元素不被实现。** 设计师为模型图上下文而包含的键盘、状态栏、导航返回按钮和其他 iOS 提供的 UI 会自动跳过。

**项目依赖优先。** 在编写任何代码之前，代理检查项目已使用哪些库并遵循既有模式。

## 贡献

欢迎贡献！如果你有翻译表的改进、额外的组件映射或更好的参考材料——请提交 PR。

贡献时：
* 保持 SKILL.md 聚焦于工作流——详细映射放在 `references/` 中
* 在连接 MCP 服务器的情况下针对真实 Figma 设计测试更改
* 遵循 [Agent Skills 开放格式](https://agentskills.io/home) 结构
