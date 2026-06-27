# iOS 代码审计技能

一个代理技能，为 iOS 或 macOS Swift 项目生成可导航的 `CODE_AUDIT.md`——涵盖缺陷、死代码、Swift 并发问题、已弃用的 API、安全、性能和 SwiftUI 质量——每条发现项都引用到 `path/to/file.swift:LINE`。

本技能是**只读**的：它永远不会修改你的代码。它产出一份交付物 `CODE_AUDIT.md`，写入被审计仓库的根目录。

---

## 适用人群

iOS 和 macOS Swift 开发者，希望对代码库进行一次性、按严重性分级的审计——那种在重构冲刺、重大版本发布或收购之前会委托进行的审查。产出物是一份单一的 Markdown 报告，你可以交给队友、作为 issue 提交，或在几个 PR 中逐步消化。

---

## 安装

### 选项 A —— `npx skills add`（推荐）

```bash
npx skills add https://github.com/jazzychad/ios-code-audit --skill ios-code-audit
```

### 选项 B —— 手动 clone

```bash
git clone https://github.com/jazzychad/ios-code-audit ~/.claude/skills/ios-code-audit
```

### 选项 C —— 本地项目安装

在你的本地项目目录下：
```bash
mkdir -p .claude/skills && git clone https://github.com/jazzychad/ios-code-audit .claude/skills/ios-code-audit
```

重启 Claude Code（或运行 `/skills` 刷新），该技能就会以 `ios-code-audit` 的名称出现。

---

## 你会得到什么

`CODE_AUDIT.md` 的结构便于分诊——章节编号在编辑后保持不变，因此你可以在 issue 或 PR 中以"§5.4"的方式引用发现项。章节包括：

- **执行摘要** —— 前 5-10 条最高影响的发现项，每条一行
- **快速收益** —— 值得先解决的 ≤30 分钟修复
- **并发** —— Swift 6 / 严格并发问题，锚定到实际的编译器警告
- **API 现代化** —— 在你的部署目标下可用的弃用项及替代 API
- **缺陷 / 逻辑错误** —— 强制解包、缺失的授权处理、循环引用、竞态条件
- **安全** —— 硬编码的密钥、令牌存储、调试与生产 URL 的切换
- **性能** —— 每帧分配、`CIContext` 生命周期、冗余解码、主线程热路径
- **SwiftUI / UI** —— `@State`/`@Observable` 误用、视图 body 内的工作、无障碍缺口
- **死代码、重复代码、重构候选** —— 包括超大文件和未解决的 `TODO`/`FIXME`
- **横切建议** —— 值得在整个仓库范围应用的模式
- **未审计的内容** —— 显式的范围外清单
- **核实** —— 证明每条 Critical / High 主张的确切代码行

本技能强制执行的运作原则：

- **只读。** 不修改任何代码。
- **每条 Critical / High 发现项都引用 `file.swift:LINE`。** "遍布代码库"会被拒绝。
- **严重性保守。** Critical 意味着崩溃、数据丢失、内存损坏或安全暴露——并且每条 Critical 主张在写入报告之前，都会通过打开引用文件进行抽查核实。
- **发现项按根因分组。** 一个缺失的 `@MainActor` 注解触发七条警告，是一条列出七个位置的发现项，而不是七条发现项。

---

## 依赖

在运行本技能*之前*先配置好这些。

### 1. Xcode 原生 MCP 服务器（推荐）

本技能使用 Xcode 内置的 MCP 服务器，提取结构化的编译器警告，作为审计中并发和弃用部分的权威输入。没有它，本技能会回退到解析 `xcodebuild` 输出，可用但噪声更大。

按照 Apple 官方指南启用它：
👉 **<https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode>**

### 2. `swiftui-expert-skill`（如果你的项目使用 SwiftUI，则必需）

工作流程的第 4 步将 SwiftUI 审查委托给一个专门的专家技能。如果你的项目包含任何 SwiftUI 视图，请安装：

👉 **<https://github.com/AvdLee/SwiftUI-Agent-Skill>**

```bash
npx skills add https://github.com/AvdLee/SwiftUI-Agent-Skill --skill swiftui-expert-skill
```

如果你的项目是纯 UIKit / AppKit，此依赖是可选的——SwiftUI 审查步骤会被跳过。

---

## 用法

在你的 iOS/macOS Swift 项目根目录下打开 Claude Code，自然地提问——本技能会在以下短语上激活：

- "运行一次代码审计"
- "对代码库做全面审查"
- "找出技术债"
- "我该清理什么？"

或者显式调用：

```
/ios-code-audit
```

技能完成后，报告会写入 `<repo-root>/CODE_AUDIT.md`。本技能会覆盖任何已存在的 `CODE_AUDIT.md`——如果你想保留之前的审计结果，请先 `git mv` 它们。

如果你的项目有 `CLAUDE.md` 列出了"请勿编辑"的目录（例如 `Dead/`、`Archive/`），本技能会读取并自动排除它们。

---

## 工作原理

一个 6 步工作流程：

1. **确定范围** —— 统计 Swift 文件 / LOC，识别热点文件（最大、核心状态）。
2. **捕获编译器警告** —— 通过 Xcode MCP 服务器（首选）或 `xcodebuild`（备选）。这成为并发审计的权威输入，因此技能永远不必猜测某条警告是否存在。
3. **三个并行的 Explore 代理** ——
   - **代理 A：** 并发与 API 现代化（喂入第 2 步的警告）
   - **代理 B：** 死代码、重复代码、重构候选
   - **代理 C：** 缺陷、逻辑错误、安全、性能
4. **SwiftUI 专家审查** —— 对 SwiftUI 界面调用 `swiftui-expert-skill`（纯 UIKit/AppKit 时跳过）。
5. **核实每条 Critical 主张** —— 打开引用的行并确认。对任何无法重现的内容降级或丢弃。
6. **综合 `CODE_AUDIT.md`** —— 使用稳定的带章节编号模板，以便发现项可以按 ID 引用。

完整的工作流程，包括各代理的简报和报告骨架，位于 [`SKILL.md`](SKILL.md) 和 [`references/`](references/) 目录中。

---

## 本技能不涵盖的内容

- **领域特定代码的算法正确性。** 只呈现显而易见的问题。
- **构建设置、scheme 配置、Xcode 项目结构**，超出共享 scheme 中可见内容的范围。
- **第三方依赖的内部实现。** SPM 包被视为黑盒。
- **深度的测试覆盖评估。** 仅快速扫视。
- **本地化措辞。** 审计可以标注未翻译的字符串，但不评估翻译质量。
- **Instruments / 运行时剖析。** 本技能识别*潜在的*热路径，但不运行 trace。为此，请单独使用 [`swiftui-expert-skill`](https://github.com/AvdLee/SwiftUI-Agent-Skill) 及其 trace 工具。

---

## 贡献

`SKILL.md`、`references/agent-prompts.md` 和 `references/report-template.md` 这三个文件构成一条流水线——逐条发现项的模板（`位置` / `问题` / `原因` / `行动` / `严重性`）必须在三者中保持一致，以使综合过程保持机械化。编辑规则见 [`CLAUDE.md`](CLAUDE.md)。

欢迎提交 issue 和 PR。

---

## 许可证

[MIT](LICENSE)。
