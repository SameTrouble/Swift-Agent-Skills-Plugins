# 设计规格说明书：Swift-Agent-Skills 三平台插件支持

**日期**：2026-07-01
**状态**：已批准
**基线**：HEAD `9916625`（先 reset 工作区到干净状态）

## 1. 背景与目标

### 1.1 背景

Swift-Agent-Skills 仓库 vendored 了 31 个 Swift/Apple 平台 AI agent skills，源码组织为嵌套结构 `skills/<category>/<name>/SKILL.md`（16 个 category，31 个 skill）。`scripts/build.sh` 将嵌套源扁平化为 `dist/skills/<name>/SKILL.md`，`dist/` 已提交到 git。

当前 HEAD（`9916625`）已完成一轮三平台插件化基础工作：Claude Code 入口（`.claude-plugin/plugin.json` + `marketplace.json`）已就位，但工作区处于半回滚状态（`marketplace.json` 和设计文档被删除、`build.sh` 丢失可执行权限、`.gitignore` 被修改）。Codex 和 OpenCode 的平台入口完全缺失。

参考项目 superpowers-zh 用"单一 `skills/` 源 + 三套平台入口目录"的方式支持 Claude Code、Codex、OpenCode 三平台，其 skills 本身就是扁平结构 `skills/<name>/SKILL.md`，三平台可直接读取。

### 1.2 目标

在当前 HEAD 基线上，先 reset 工作区到干净状态，然后照搬 superpowers 的多平台入口模式，为 Codex 和 OpenCode 补齐平台入口，使本项目支持三平台插件安装。三个平台都指向 `dist/skills/` 扁平产物。

### 1.3 非目标（YAGNI）

- 不创建 `hooks/` 目录——本项目无 bootstrap 入门技能，不需要会话启动注入
- 不创建根目录 `marketplace.json` 副本——Claude Code 用 `.claude-plugin/marketplace.json`，Codex 用 `.agents/plugins/marketplace.json`，各自独立
- 不补全 skill 内的 references 文档——超出本次范围
- 不做 bootstrap 文本注入——31 个技能都是独立的 Swift 领域技能，无统一入门技能
- 不改动 `skills/` 嵌套源结构和 `sync.sh` 上游同步逻辑

## 2. 技术调研结论

通过查阅三平台官方文档，确认了 skill 发现机制的关键约束：

| 平台 | 发现机制 | 支持嵌套？ | 关键文档依据 |
|------|---------|-----------|-------------|
| Claude Code | `skills/<name>/SKILL.md`，一层深 | 否 | 官方文档所有示例均为一层，未提及递归扫描 |
| Codex | `skills/<skill-name>/SKILL.md`，一层深 | 否 | 文档结构图为单层 `my-skill/SKILL.md` |
| OpenCode | `skills/*/SKILL.md`，单层 glob | 否 | 文档明确 `skills/*/SKILL.md`，name 须匹配目录名 |

**结论**：三个平台都不支持嵌套目录，必须有扁平的 `skills/<name>/SKILL.md` 视图。本项目的嵌套源不能被平台直接读取，必须依赖 `dist/skills/` 扁平产物。

### 2.1 OpenCode 的特殊性

OpenCode 官方文档未记载 `skills.paths` 配置、`pi.skills` 字段和 `experimental.chat.messages.transform` 钩子。但 superpowers-zh 的 OpenCode JS 插件使用了这些特性，且已在 zcode/opencode 环境中实际部署运行。本次设计照搬 superpowers 的方式，基于这些已验证可用的特性。

## 3. 架构设计

### 3.1 核心原则

1. **保留嵌套源**：`skills/<category>/<name>/` 不变，`sync.sh` 上游同步依赖此结构
2. **保留扁平产物**：`build.sh` 生成 `dist/skills/<name>/`，三平台共用，已提交 git
3. **平台入口隔离**：`.claude-plugin/`、`.codex-plugin/`(+`.agents/`)、`.opencode/` 三个互不重叠的目录
4. **无 bootstrap**：不创建 hooks，不做会话启动注入

### 3.2 最终目录布局

新增项标 🆕，恢复项标 ↩️：

```
Swift-Agent-Skills/
├── .claude-plugin/
│   ├── plugin.json              # 现有，不改
│   └── marketplace.json         # ↩️ 从工作区删除状态恢复
├── .codex-plugin/               # 🆕 Codex 入口
│   └── plugin.json
├── .agents/                     # 🆕 Codex marketplace 入口
│   └── plugins/
│       └── marketplace.json
├── .opencode/                   # 🆕 OpenCode 入口
│   └── plugins/
│       └── swift-agent-skills.js
├── package.json                 # 🆕 OpenCode 包定义
├── skills/                      # 嵌套源（不变）
├── dist/skills/                 # 扁平产物（不变）
├── scripts/
│   ├── build.sh                 # ↩️ 恢复可执行权限
│   ├── sync.sh                  # 不变
│   └── catalog.json             # 不变
├── README.md                    # 更新三平台安装说明
└── （其他现有文件不变）
```

### 3.3 数据流

```
sync.sh                    build.sh                    各平台入口
─────────                  ─────────                   ─────────
上游 repos  ──>  skills/<category>/<name>/  ──>  dist/skills/<name>/  <── 三平台读取
                 （嵌套源，真相源）            （扁平产物，已提交 git）
                                              │
                          ┌───────────────────┼───────────────────┐
                          ▼                   ▼                   ▼
                   .claude-plugin/     .codex-plugin/       .opencode/ + package.json
                   （skills 指向        （skills 指向         （pi.skills 指向
                    dist/skills）        dist/skills）         dist/skills）
```

## 4. 各平台清单文件设计

### 4.1 Claude Code（恢复 + 保持现状）

#### `.claude-plugin/plugin.json`（现有，不改）

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for SwiftUI, SwiftData, Swift concurrency, testing, and more.",
  "author": { "name": "Paul Hudson", "url": "https://hackingwithswift.com" },
  "license": "MIT",
  "repository": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "skills": "./dist/skills"
}
```

#### `.claude-plugin/marketplace.json`（从 HEAD 恢复）

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "swift-agent-skills",
  "description": "31 curated Swift and Apple platform agent skills for SwiftUI, SwiftData, Swift concurrency, testing, and more.",
  "owner": { "name": "Paul Hudson", "url": "https://hackingwithswift.com" },
  "plugins": [
    {
      "name": "swift-agent-skills",
      "category": "development",
      "source": ".",
      "homepage": "https://github.com/SameTrouble/Swift-Agent-Skills"
    }
  ]
}
```

**安装方式**：
- Marketplace：`/plugin marketplace add SameTrouble/Swift-Agent-Skills` + `/plugin install swift-agent-skills`
- Git clone：clone 到 `~/.claude/plugins/swift-agent-skills`，Claude Code 自动发现 `.claude-plugin/plugin.json`

### 4.2 Codex（新建）

#### `.codex-plugin/plugin.json`

照搬 superpowers 的 `.codex-plugin/plugin.json` 结构，改成本项目信息。`skills` 指向 `./dist/skills/`，包含 `interface` 展示元数据（不设 `composerIcon`/`logo`，仓库无对应 assets 避免死链）：

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for SwiftUI, SwiftData, Swift concurrency, testing, and more.",
  "author": { "name": "Paul Hudson", "url": "https://hackingwithswift.com" },
  "homepage": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "repository": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "license": "MIT",
  "keywords": ["swift", "swiftui", "swiftdata", "ios", "apple", "skills"],
  "skills": "./dist/skills/",
  "interface": {
    "displayName": "Swift Agent Skills",
    "shortDescription": "31 Swift and Apple platform agent skills",
    "longDescription": "Curated Swift and Apple platform agent skills covering SwiftUI, SwiftData, Swift concurrency, testing, App Store, accessibility, and more.",
    "developerName": "Paul Hudson",
    "category": "Coding",
    "capabilities": ["Interactive", "Read", "Write"],
    "defaultPrompt": ["Help me write SwiftUI code.", "Review my Swift code."],
    "websiteURL": "https://github.com/SameTrouble/Swift-Agent-Skills",
    "brandColor": "#F05138"
  }
}
```

#### `.agents/plugins/marketplace.json`

Codex 市场清单，source 用 `url` 类型指向 `./`（照搬 superpowers 模式）：

```json
{
  "name": "swift-agent-skills",
  "interface": { "displayName": "Swift Agent Skills" },
  "plugins": [
    {
      "name": "swift-agent-skills",
      "source": { "source": "url", "url": "./" },
      "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
      "category": "Developer Tools"
    }
  ]
}
```

**安装方式**：
- Marketplace：`codex plugin marketplace add SameTrouble/Swift-Agent-Skills`，然后在 Codex 的 Plugins 界面安装
- Drop-in：clone 后在 `~/.codex/config.toml` 逐 skill 配置 `[[skills.config]] path = ".../dist/skills/<name>"`

### 4.3 OpenCode（新建）

#### `package.json`

照搬 superpowers 的 `package.json` 结构。`main` 指向 JS 插件，`pi.skills` 指向 `./dist/skills`：

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for OpenCode",
  "type": "module",
  "main": ".opencode/plugins/swift-agent-skills.js",
  "keywords": ["pi-package", "skills", "swift", "swiftui"],
  "pi": { "skills": ["./dist/skills"] }
}
```

#### `.opencode/plugins/swift-agent-skills.js`

照搬 superpowers 的 JS 插件结构，但**精简**为只做 skills 路径注册：

- **保留**：`config` 钩子——把 `dist/skills` 注册到 OpenCode 的 `config.skills.paths`，无需符号链接
- **删除**：`experimental.chat.messages.transform` 钩子——bootstrap 注入逻辑（本项目无入门技能）
- **删除**：frontmatter 解析器——仅 bootstrap 注入需要它
- **删除**：工具映射附录——superpowers 特有的平台工具映射，与本项目无关

插件逻辑概要（参考 superpowers-zh JS 插件的 `config` 钩子实现）：
1. 导出默认的插件函数，接收 `{ client, directory }` context
2. 计算 skills 目录：`path.resolve(__dirname, '../../dist/skills')`（从 `.opencode/plugins/` 回溯两级到仓库根再进 `dist/skills/`）
3. `config` 钩子：确保 `config.skills.paths` 数组存在，把 `dist/skills` 绝对路径 push 进去（如尚未包含）
4. 不需要 `OPENCODE_CONFIG_DIR` 环境变量——该变量在 superpowers 中仅用于 bootstrap 注入逻辑，本次已删除

**安装方式**：
- 全局：`opencode.json` 的 `plugin` 数组加 git URL 或本地路径
- 项目级：clone 到 `~/.config/opencode/plugins/swift-agent-skills`
- Drop-in：clone 后在 `opencode.json` 配置 plugin 路径

## 5. README 更新设计

当前 README 已有三平台安装说明（提交 `c290422`），但 OpenCode 部分基于未记载的 `skills.paths` 配置。更新内容：

1. **Claude Code 章节**：保持现有 marketplace + git clone 双路径说明，无需大改
2. **Codex 章节**：更新为 marketplace 安装（`codex plugin marketplace add`）+ drop-in 配置两条路径
3. **OpenCode 章节**：替换 `skills.paths` 说明为 `package.json` + JS 插件方式（plugin 数组加 git URL 或 clone 到 `~/.config/opencode/plugins/`）
4. **迁移说明**：保留现有"旧 TS 插件机制已移除"的迁移说明

## 6. 实施步骤

按依赖顺序执行：

1. **恢复工作区**：`git reset --hard HEAD` 恢复到 `9916625` 干净状态（恢复 `marketplace.json`、设计文档、`build.sh` 可执行权限、`.gitignore`）
2. **创建 Codex 入口**：
   - `.codex-plugin/plugin.json`
   - `.agents/plugins/marketplace.json`
3. **创建 OpenCode 入口**：
   - `package.json`
   - `.opencode/plugins/swift-agent-skills.js`
4. **更新 README**：三平台安装说明
5. **验证**：
   - `./scripts/build.sh` 重新生成 `dist/skills/` 确保扁平产物完整
   - 用 `python3 -m json.tool` 校验所有 JSON 清单语法正确
   - 确认各平台入口的 `skills`/`pi.skills` 路径都指向 `dist/skills`

## 7. 归属与许可

- 所有清单的 `author` 保留原作者 Paul Hudson（`https://hackingwithswift.com`）
- `homepage`/`repository` 指向 `https://github.com/SameTrouble/Swift-Agent-Skills`
- 许可证：MIT
- `brandColor` 用 Swift 橙色 `#F05138`
