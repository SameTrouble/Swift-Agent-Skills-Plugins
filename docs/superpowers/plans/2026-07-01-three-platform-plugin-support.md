# Swift-Agent-Skills 三平台插件支持 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Swift-Agent-Skills 项目补齐 Codex 和 OpenCode 平台入口，使其像 superpowers 一样支持三平台插件安装，三平台都指向 `dist/skills/` 扁平产物。

**Architecture:** 保留 `skills/<category>/<name>/` 嵌套源 + `build.sh` 生成的 `dist/skills/<name>/` 扁平产物。新增 `.codex-plugin/`、`.agents/`、`.opencode/`、`package.json` 四个平台入口，各自指向 `dist/skills/`。不创建 hooks（无 bootstrap 需求）。

**Tech Stack:** JSON 清单文件（Claude Code/Codex marketplace 格式）、ES Module JavaScript（OpenCode 插件）、Markdown（README）。

## Global Constraints

- 基线：HEAD `9916625`，工作区已 reset 到干净状态
- 三平台 skills 路径都指向 `./dist/skills/`（Codex 的 `skills` 字段带尾斜杠 `./dist/skills/`）
- 归属：`author` 为 Paul Hudson（`https://hackingwithswift.com`），`homepage`/`repository` 为 `https://github.com/SameTrouble/Swift-Agent-Skills`
- 许可证：MIT
- 不创建 `hooks/` 目录、不创建根目录 `marketplace.json` 副本
- OpenCode JS 插件只做 skills 路径注册（config 钩子），不做 bootstrap 注入
- 所有 JSON 文件用 2 空格缩进

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `.codex-plugin/plugin.json` | 创建 | Codex 插件清单，`skills` 指向 `./dist/skills/`，含 `interface` 展示元数据 |
| `.agents/plugins/marketplace.json` | 创建 | Codex 市场清单，source 用 url 类型指向 `./` |
| `package.json` | 创建 | OpenCode 包定义，`pi.skills` 指向 `./dist/skills`，`main` 指向 JS 插件 |
| `.opencode/plugins/swift-agent-skills.js` | 创建 | OpenCode JS 插件，config 钩子注册 `dist/skills` 到 `config.skills.paths` |
| `README.md` | 修改 | 更新 Codex 和 OpenCode 安装说明章节 |

---

### Task 1: Codex 插件清单

**Files:**
- Create: `.codex-plugin/plugin.json`

**Interfaces:**
- Produces: `.codex-plugin/plugin.json` — Codex 读取此文件发现插件名、版本、skills 目录和展示元数据

- [ ] **Step 1: 创建 `.codex-plugin/plugin.json`**

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for SwiftUI, SwiftData, Swift concurrency, testing, and more.",
  "author": {
    "name": "Paul Hudson",
    "url": "https://hackingwithswift.com"
  },
  "homepage": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "repository": "https://github.com/SameTrouble/Swift-Agent-Skills",
  "license": "MIT",
  "keywords": [
    "swift",
    "swiftui",
    "swiftdata",
    "ios",
    "apple",
    "skills"
  ],
  "skills": "./dist/skills/",
  "interface": {
    "displayName": "Swift Agent Skills",
    "shortDescription": "31 Swift and Apple platform agent skills",
    "longDescription": "Curated Swift and Apple platform agent skills covering SwiftUI, SwiftData, Swift concurrency, testing, App Store, accessibility, and more.",
    "developerName": "Paul Hudson",
    "category": "Coding",
    "capabilities": [
      "Interactive",
      "Read",
      "Write"
    ],
    "defaultPrompt": [
      "Help me write SwiftUI code.",
      "Review my Swift code."
    ],
    "websiteURL": "https://github.com/SameTrouble/Swift-Agent-Skills",
    "brandColor": "#F05138"
  }
}
```

- [ ] **Step 2: 验证 JSON 语法**

Run: `python3 -m json.tool .codex-plugin/plugin.json > /dev/null && echo "JSON valid"`
Expected: `JSON valid`

- [ ] **Step 3: 提交**

```bash
git add .codex-plugin/plugin.json
git commit -m "Add Codex plugin manifest pointing to dist/skills"
```

---

### Task 2: Codex 市场清单

**Files:**
- Create: `.agents/plugins/marketplace.json`

**Interfaces:**
- Produces: `.agents/plugins/marketplace.json` — Codex 通过此文件发现可安装的插件，source 指向 `./`

- [ ] **Step 1: 创建 `.agents/plugins/marketplace.json`**

```json
{
  "name": "swift-agent-skills",
  "interface": {
    "displayName": "Swift Agent Skills"
  },
  "plugins": [
    {
      "name": "swift-agent-skills",
      "source": {
        "source": "url",
        "url": "./"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

- [ ] **Step 2: 验证 JSON 语法**

Run: `python3 -m json.tool .agents/plugins/marketplace.json > /dev/null && echo "JSON valid"`
Expected: `JSON valid`

- [ ] **Step 3: 提交**

```bash
git add .agents/plugins/marketplace.json
git commit -m "Add Codex marketplace manifest for plugin discovery"
```

---

### Task 3: OpenCode 包定义

**Files:**
- Create: `package.json`

**Interfaces:**
- Produces: `package.json` — OpenCode 识别 `pi-package` 关键字和 `pi.skills` 字段，`main` 指向 JS 插件

- [ ] **Step 1: 创建 `package.json`**

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "31 curated Swift and Apple platform agent skills for OpenCode",
  "type": "module",
  "main": ".opencode/plugins/swift-agent-skills.js",
  "keywords": [
    "pi-package",
    "skills",
    "swift",
    "swiftui"
  ],
  "pi": {
    "skills": [
      "./dist/skills"
    ]
  }
}
```

- [ ] **Step 2: 验证 JSON 语法**

Run: `python3 -m json.tool package.json > /dev/null && echo "JSON valid"`
Expected: `JSON valid`

- [ ] **Step 3: 提交**

```bash
git add package.json
git commit -m "Add OpenCode package.json with pi.skills pointing to dist/skills"
```

---

### Task 4: OpenCode JS 插件

**Files:**
- Create: `.opencode/plugins/swift-agent-skills.js`

**Interfaces:**
- Consumes: `package.json` 的 `main` 字段指向此文件
- Produces: 默认导出的异步插件函数，返回 `{ config }` 钩子对象，把 `dist/skills` 绝对路径注册到 `config.skills.paths`

**参考实现：** superpowers-zh 的 `.opencode/plugins/superpowers-zh.js`，删除 bootstrap 注入（`experimental.chat.messages.transform` 钩子）、frontmatter 解析器、工具映射附录，只保留 `config` 钩子。

- [ ] **Step 1: 创建 `.opencode/plugins/swift-agent-skills.js`**

```javascript
/**
 * Swift Agent Skills 插件 for OpenCode.ai
 *
 * 通过 config 钩子自动注册 skills 目录（无需符号链接）。
 * 本插件不做 bootstrap 注入——31 个技能都是独立的 Swift 领域技能，无统一入门技能。
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const SwiftAgentSkillsPlugin = async ({ client, directory }) => {
  // dist/skills 相对于 .opencode/plugins/ 的路径：回溯两级到仓库根，再进 dist/skills
  const skillsDir = path.resolve(__dirname, '../../dist/skills');

  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};

export default SwiftAgentSkillsPlugin;
```

- [ ] **Step 2: 验证 JS 语法**

Run: `node --check .opencode/plugins/swift-agent-skills.js && echo "JS syntax valid"`
Expected: `JS syntax valid`

- [ ] **Step 3: 提交**

```bash
git add .opencode/plugins/swift-agent-skills.js
git commit -m "Add OpenCode JS plugin to auto-register dist/skills path"
```

---

### Task 5: 更新 README 安装说明

**Files:**
- Modify: `README.md:193-248`（Codex 和 OpenCode 章节）

**Interfaces:**
- Consumes: Task 1-4 创建的平台入口文件

**改动范围：**
1. Codex 章节（193-216 行）：替换为 `codex plugin marketplace add` + drop-in 两条路径
2. OpenCode 章节（218-248 行）：替换 `skills.paths` 说明为 `package.json` + JS 插件方式

- [ ] **Step 1: 替换 Codex 章节（193-216 行）**

将原 Codex 章节（从 `### Codex` 到 `### OpenCode` 之前）替换为：

```markdown
### Codex

Codex discovers skills via `.codex-plugin/plugin.json` and the marketplace manifest at `.agents/plugins/marketplace.json`.

**Option A — Marketplace install (recommended):**

```
codex plugin marketplace add SameTrouble/Swift-Agent-Skills
```

Then install the plugin via Codex's `/plugins` command or sidebar. Skills load from `dist/skills/` at user scope.

**Option B — Drop-in (per-skill path):**

Clone the repo, then add each skill you want to `~/.codex/config.toml`:

```toml
[[skills.config]]
path = "/absolute/path/to/Swift-Agent-Skills/dist/skills/swiftui-pro"
enabled = true
```
```

- [ ] **Step 2: 替换 OpenCode 章节（218-248 行）**

将原 OpenCode 章节（从 `### OpenCode` 到 `### Syncing skills` 之前）替换为：

```markdown
### OpenCode

OpenCode discovers skills via the `package.json` (`pi.skills` field) and the JS plugin at `.opencode/plugins/swift-agent-skills.js`, which auto-registers `dist/skills/` to `config.skills.paths`.

**Option A — Plugin install (recommended):**

Add the git URL to the `plugin` array in your `opencode.json` (global at `~/.config/opencode/opencode.json` or project-level):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["https://github.com/SameTrouble/Swift-Agent-Skills"]
}
```

**Option B — Git clone (local):**

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/swift-agent-skills
```

Local plugins in `~/.config/opencode/plugins/` are auto-discovered — no config entry needed. The JS plugin automatically registers `dist/skills/` on startup.

#### Migrating from the old opencode plugin

If you previously installed via `plugin: ["swift-agent-skills@git+..."]` or manual `skills.paths` config, switch to the plugin-based install shown above. The old TS plugin mechanism has been removed; the new JS plugin auto-registers the skills path.
```

- [ ] **Step 3: 验证 README 无残留旧引用**

Run: `grep -n "skills.paths\|skills\.config\|source_type\|\[marketplaces" README.md || echo "No stale references"`
Expected: `No stale references`（drop-in 的 `[[skills.config]]` 是 Codex 的合法配置，不在此检查范围——用更精确的模式）

修正——Codex drop-in 的 `[[skills.config]]` 是合法的，只检查 OpenCode 旧引用：

Run: `grep -n 'skills.paths\|"skills":.*"paths"' README.md || echo "No stale OpenCode references"`
Expected: `No stale OpenCode references`

- [ ] **Step 4: 提交**

```bash
git add README.md
git commit -m "Update README with Codex marketplace and OpenCode plugin install instructions"
```

---

### Task 6: 最终验证

**Files:**
- 无文件操作，纯验证

- [ ] **Step 1: 重新构建 dist/skills 确保扁平产物完整**

Run: `./scripts/build.sh`
Expected: `Build complete: 31 built, <N> warned, 0 failed.`

- [ ] **Step 2: 校验所有 JSON 清单语法**

Run:
```bash
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json .agents/plugins/marketplace.json package.json; do
  python3 -m json.tool "$f" > /dev/null && echo "OK: $f" || echo "FAIL: $f"
done
```
Expected: 全部 `OK:`

- [ ] **Step 3: 校验 JS 插件语法**

Run: `node --check .opencode/plugins/swift-agent-skills.js && echo "JS OK"`
Expected: `JS OK`

- [ ] **Step 4: 确认各平台入口路径都指向 dist/skills**

Run:
```bash
echo "=== Claude Code ===" && grep -o '"skills": "[^"]*"' .claude-plugin/plugin.json
echo "=== Codex ===" && grep -o '"skills": "[^"]*"' .codex-plugin/plugin.json
echo "=== OpenCode ===" && grep -o '"./dist/skills"' package.json
```
Expected:
```
=== Claude Code ===
"skills": "./dist/skills"
=== Codex ===
"skills": "./dist/skills/"
=== OpenCode ===
"./dist/skills"
```

- [ ] **Step 5: 确认目录结构完整**

Run:
```bash
echo "=== Platform entries ===" && \
ls -la .claude-plugin/ .codex-plugin/ .agents/plugins/ .opencode/plugins/ && \
echo "=== Root package.json ===" && ls -la package.json
```
Expected: 各目录下都有对应的清单/插件文件，`package.json` 存在

- [ ] **Step 6: 确认 git 状态干净**

Run: `git status`
Expected: `nothing to commit, working tree clean`

---

## 自审

**1. 规格覆盖：**
- 规格第 4.1 节 Claude Code（恢复 marketplace.json）→ 已在 brainstorming 阶段通过 `git reset --hard HEAD` 完成，marketplace.json 已恢复。无需额外任务。✅
- 规格第 4.2 节 Codex（.codex-plugin/plugin.json + .agents/plugins/marketplace.json）→ Task 1 + Task 2。✅
- 规格第 4.3 节 OpenCode（package.json + JS 插件）→ Task 3 + Task 4。✅
- 规格第 5 节 README 更新 → Task 5。✅
- 规格第 6 节实施步骤 1（reset）→ 已在 brainstorming 阶段完成。✅
- 规格第 6 节实施步骤 5（验证）→ Task 6。✅

**2. 占位符扫描：** 无 TBD/TODO，每个步骤都有完整代码和确切命令。✅

**3. 类型一致性：**
- `dist/skills` 路径在 plugin.json（`./dist/skills`）、.codex-plugin/plugin.json（`./dist/skills/`）、package.json（`./dist/skills`）、JS 插件（`../../dist/skills`）中一致。✅
- 插件函数名 `SwiftAgentSkillsPlugin` 在 package.json 的 `main` 和 JS 文件的导出名一致。✅
- Codex marketplace 的 `source.url: "./"` 与 superpowers 一致。✅
