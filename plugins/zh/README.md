# Swift Agent Skills（中文版）

本目录是 Swift-Agent-Skills 的中文插件包，包含全部 31 个技能的中文译文。技能内容随英文版同步更新并翻译。

## 中文技能清单

| 技能名 | 分类 | 状态 | 上游同步版本 |
|--------|------|------|-------------|
| swiftui-pro | SwiftUI | 已翻译 | 1.1 |
| swiftui-ui-patterns | SwiftUI | 已翻译 | — |
| swiftui-design-principles | SwiftUI | 已翻译 | 1.1.1 |
| swiftui-view-refactor | SwiftUI | 已翻译 | — |
| swiftui-performance-audit | 性能 | 已翻译 | — |
| swiftdata-pro | SwiftData | 已翻译 | 1.0 |
| swiftdata-expert | SwiftData | 已翻译 | — |
| swift-concurrency-pro | 并发 | 已翻译 | 1.0 |
| swift-concurrency-expert | 并发 | 已翻译 | — |
| swift-concurrency-expert-dimillian | 并发 | 已翻译 | — |
| swift-testing-pro | 测试 | 已翻译 | 1.0 |
| swift-testing-agent-skill | 测试 | 已翻译 | — |
| swift-testing-expert | 测试 | 已翻译 | — |
| swift-api-design-guidelines | 语言 | 已翻译 | — |
| swift-formatstyle | 语言 | 已翻译 | 1.0 |
| swift-accessibility | 无障碍 | 已翻译 | — |
| ios-accessibility | 无障碍 | 已翻译 | — |
| apple-accessibility | 无障碍 | 已翻译 | 1.3.0 |
| app-intents | App Intents | 已翻译 | 1.2.0 |
| app-store-connect-cli | App Store | 已翻译 | — |
| app-store-changelog | App Store | 已翻译 | — |
| app-store-aso-optimization | App Store | 已翻译 | — |
| app-store-review | App Store | 已翻译 | 1.1.0 |
| swift-architecture | 架构 | 已翻译 | — |
| core-data-expert | Core Data | 已翻译 | — |
| swift-focusengine-pro | 焦点 | 已翻译 | 1.7.1 |
| swift-security-expert | 安全 | 已翻译 | — |
| ios-code-audit | 审计 | 已翻译 | — |
| ios-simulator | 工具 | 已翻译 | 1.5.0 |
| figma-to-swiftui | 工具 | 已翻译 | — |
| writing-for-interfaces | 界面文案 | 已翻译 | — |

> 全部 31 个技能已翻译完成。新增或同步翻译后，请在此表格登记。

## 翻译流程

1. **拷贝**：从 `plugins/en/skills/<name>/` 拷贝到 `plugins/zh/skills/<name>/`
2. **翻译**：逐文件翻译 `SKILL.md` 和 `references/*.md`
3. **保留 frontmatter `name` 字段不变**：技能内部标识符保持英文（如 `name: swiftui-pro`），仅 `description` 翻译为中文
4. **代码示例不翻译**：Swift 代码、命令、文件路径保持原样
5. **提交**：commit message 标注语言，如 `zh: translate swiftui-pro`
6. **登记**：在本文件上方表格更新状态

## 上游同步

`scripts/sync.sh` 更新英文版后，维护者通过以下方式同步中文版：

```bash
git diff plugins/en/skills/<name>/
```

手动将变更同步到对应中文版。sync.sh 绝不触碰本目录（`plugins/zh/`）。

## 安装

见根目录 [README.md](../../README.md) 的中文安装说明。
