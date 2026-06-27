# Apple App Store ASO 优化技能

> **已迁移。** 此技能现位于合并后的 [TimBroddin/skills](https://github.com/TimBroddin/skills) 仓库中，以便所有我的代理技能从一处安装。

## 新的安装方式

### `skills` CLI（适用于任何代理 — Claude Code、Codex、Cursor、OpenCode 等）

```bash
npx skills add TimBroddin/skills --skill app-store-aso
```

### Claude Code 插件（安装仓库中的所有技能）

```
/plugin install TimBroddin/skills
```

## 功能介绍

基于 ASO 最佳实践生成优化的 Apple App Store 元数据：

- 应用名称、副标题、推广文本、描述、关键词、新功能 — 全部根据 Apple 的字符限制进行验证
- 竞争分析和截图策略（包括针对 2025 年 6 月 OCR 索引更新的说明文字优化）
- 与 [astro-mcp-server](https://github.com/TimBroddin/astro-mcp-server) 配合进行关键词研究，与 [krankie](https://github.com/timbroddin/krankie) 配合进行排名追踪

完整文档位于合并后的仓库中：<https://github.com/TimBroddin/skills/tree/main/skills/app-store-aso>。

## 许可证

MIT — 详见 [LICENSE](LICENSE)。
