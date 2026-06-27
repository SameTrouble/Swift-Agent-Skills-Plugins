# SwiftUI 设计原则

本仓库包含一个智能体技能，用于构建精致的 SwiftUI 应用和 WidgetKit 小组件。

## 结构

- `SKILL.md` — 包含所有设计原则的技能定义
- `metadata.json` — 技能元数据（版本、作者、摘要）
- `LICENSE` — MIT 许可证

## 技能如何工作

当智能体检测到 SwiftUI 或 WidgetKit 相关任务时加载本技能。它提供：

1. 基于 4/8 的间距网格，防止任意内边距值
2. 基于字重区分的排版层级（不只是字号）
3. 系统语义色使用，而非硬编码透明度值
4. 原生 WidgetKit 模式（Gauge、containerBackground）
5. 发布前清单用于验证

本技能纯粹是指导性的——无需脚本或构建步骤。
