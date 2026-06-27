---
name: app-store-aso
description: 基于 ASO 最佳实践生成优化的 Apple App Store 元数据建议。当需要分析应用列表、优化元数据（标题、副标题、描述、关键词）、执行竞争分析或验证 App Store 列表要求时使用此技能。在涉及 App Store 优化、元数据审查或截图策略的查询时触发。
---

# Apple App Store ASO 优化

## 概述

本技能支持全面的 Apple App Store 优化（ASO）分析与元数据生成。可分析现有应用列表，遵循 Apple 指南和字符限制生成优化元数据，提供竞争洞察，并推荐截图分镜策略。

## 核心工作流程

当用户请求 ASO 优化或元数据审查时：

1. **分析应用背景**
   - 理解应用的目的、功能和目标受众
   - 识别独特价值主张和竞争优势
   - 记录用户提到的任何变更或更新

2. **加载 ASO 知识库**
   - 参考 `references/aso_learnings.md` 获取全面的 ASO 最佳实践
   - 应用竞争分析策略
   - 使用经过验证的优化模式

3. **生成优化元数据**
   - 创建优化的应用名称、副标题和推广文本
   - 撰写包含关键词优化的有吸引力的描述
   - 生成带战略性布局的关键词列表
   - 确保所有元数据符合 Apple 的字符限制

4. **验证字符数**
   - 使用 `scripts/validate_metadata.py` 验证所有元数据是否符合 Apple 的要求
   - 显示验证结果，包含字符数和限制合规情况
   - 标记任何违规项并指出所需的具体修正

5. **提供截图策略**
   - 推荐截图分镜序列
   - 建议信息层级和视觉重点区域
   - 使截图策略与元数据信息保持一致

## Apple App Store 字符限制

**需验证的关键限制：**
- **应用名称**：最多 30 个字符
- **副标题**：最多 30 个字符
- **推广文本**：最多 170 个字符
- **描述**：最多 4,000 个字符
- **关键词**：最多 100 个字符（逗号分隔，无空格）
- **新功能**：最多 4,000 个字符

## 元数据验证流程

生成建议后，始终使用验证脚本进行验证：

```bash
python scripts/validate_metadata.py
```

该脚本将：
1. 提示输入每个元数据字段
2. 计算字符数
3. 对照 Apple 的限制进行检查
4. 显示结果，包含 ✅（通过）或 ❌（失败）指示符
5. 显示确切字符数和剩余字符数

**集成模式：**
- 生成元数据建议
- 使用推荐内容运行验证脚本
- 向用户显示验证结果
- 调整任何未通过的字段并重新验证

## 输出格式

将建议结构化为：

### 📱 应用元数据建议

**应用名称**（X/30 个字符）
[优化的名称]

**副标题**（X/30 个字符）
[优化的副标题]

**推广文本**（X/170 个字符）
[推广文本]

**关键词**（X/100 个字符）
[keyword,list,no,spaces]

**描述**（X/4000 个字符）
[完整描述]

### 🎯 竞争分析
[关键洞察和定位建议]

### 📸 截图分镜策略
[带信息的截图建议有序列表]

### ✅ 验证结果
[验证脚本输出的合规情况]

## Krankie：App Store 排名追踪器

Krankie 是一款以代理为先的 CLI 工具，用于追踪 App Store 关键词排名。可用它监控关键词表现、追踪排名随时间的变化，并用真实数据指导 ASO 优化决策。

### 安装

```bash
bun install -g krankie
# or run directly
bunx krankie
```

### 关键命令

**应用管理：**
```bash
# Search for apps
krankie app search "<query>" --platform ios

# Add an app to track
krankie app create <app_id> --platform ios

# List tracked apps
krankie app list
```

**关键词追踪：**
```bash
# Add keywords to track for an app
krankie keyword add <app_id> "<keyword>" --store us

# List tracked keywords
krankie keyword list
```

**排名检查：**
```bash
# Run ranking checks for all tracked keywords
krankie check run

# View current rankings
krankie rankings

# See biggest movers (gains/losses)
krankie rankings movers

# View ranking history for a keyword
krankie rankings history <keyword_id>

# Check status of last run
krankie check status
```

**自动化：**
```bash
# Install daily cron job (default: 6 AM)
krankie cron install --hour 6

# Check cron status
krankie cron status
```

### 代理集成

所有命令支持 `--json` 标志以输出结构化数据：
```bash
krankie rankings --json
krankie app list --json
```

获取代理友好的指令：
```bash
krankie instructions --format json
```

### 数据说明

- 排名追踪位置为 1-200；null 表示在此范围之外
- 数据本地存储于 `~/.krankie/krankie.db`（SQLite）
- 每日重复检查受速率限制；使用 `--force` 覆盖
- 日志位于 `~/.krankie/check.log`

### ASO 工作流集成

1. **优化前**：使用 `krankie rankings` 建立关键词排名基线
2. **竞争分析**：追踪竞品应用及其关键词排名
3. **元数据变更后**：监控 `krankie rankings movers` 以衡量影响
4. **趋势分析**：使用 `krankie rankings history` 识别模式

## 资源

### scripts/validate_metadata.py
Python 脚本，用于根据 Apple 的字符限制验证 App Store 元数据。提供交互式验证，带有清晰的通过/失败指示符。

### references/aso_learnings.md
全面的 ASO 知识库，包含优化策略、竞争分析框架、关键词研究技巧和经过验证的最佳实践。加载此文件以指导所有 ASO 建议。
