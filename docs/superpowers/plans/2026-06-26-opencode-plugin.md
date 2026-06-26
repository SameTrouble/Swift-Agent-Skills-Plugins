# Swift-Agent-Skills opencode Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repackage the Swift-Agent-Skills repo from an awesome-list index into an installable opencode plugin that bundles 31 vendored Swift skills, auto-registered via a TypeScript config-hook plugin installable from GitHub.

**Architecture:** A TypeScript plugin (`.opencode/plugins/swift-skills.ts`) pushes a repo-local `skills/` directory onto `config.skills.paths`. A maintainer-run `scripts/sync.sh` reads `scripts/catalog.json` and clones/copies each upstream skill into `skills/<category>/<name>/`. opencode's skill loader discovers `**/SKILL.md` recursively. Install via `"plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]`.

**Tech Stack:** TypeScript (opencode plugin, type-only dep `@opencode-ai/plugin`), Bash (sync script), JSON (catalog), Markdown (skills, README).

---

## File Structure

**Create:**
- `.opencode/plugins/swift-skills.ts` — TS plugin entry; `config` hook registers `skills/` dir.
- `package.json` — npm package metadata so `git+https` install resolves; `main` points at plugin entry.
- `scripts/catalog.json` — machine-readable manifest of 31 skills (single source of truth for sync).
- `scripts/sync.sh` — bash sync script; clones upstreams, copies into `skills/`.
- `skills/<category>/<name>/SKILL.md` — 31 vendored skills (produced by sync.sh, committed).
- `tsconfig.json` — minimal TS config for `tsc --noEmit` typecheck.
- `.opencode/INSTALL.md` — install instructions for opencode users (mirrors superpowers pattern).

**Modify:**
- `README.md` — insert "Use as an opencode plugin" section before "License".
- `.gitignore` — ignore `.DS_Store` (already present) and sync temp artifacts.

---

### Task 1: Create package.json

**Files:**
- Create: `package.json`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "swift-agent-skills",
  "version": "0.1.0",
  "description": "Curated Swift and Apple platform agent skills for opencode",
  "type": "module",
  "main": ".opencode/plugins/swift-skills.ts",
  "license": "MIT",
  "devDependencies": {
    "@opencode-ai/plugin": "latest"
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add package.json
git commit -m "Add package.json for opencode plugin install"
```

---

### Task 2: Create tsconfig.json for typechecking

**Files:**
- Create: `tsconfig.json`

- [ ] **Step 1: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "allowImportingTsExtensions": true,
    "types": ["@opencode-ai/plugin"]
  },
  "include": [".opencode/plugins/**/*.ts"]
}
```

- [ ] **Step 2: Commit**

```bash
git add tsconfig.json
git commit -m "Add tsconfig.json for plugin typecheck"
```

---

### Task 3: Create the TypeScript plugin entry

**Files:**
- Create: `.opencode/plugins/swift-skills.ts`

- [ ] **Step 1: Create the plugin file**

```ts
import path from "path";
import { fileURLToPath } from "url";
import type { Plugin } from "@opencode-ai/plugin";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, "../../skills");

export default (async () => {
  return {
    config: async (config) => {
      config.skills = config.skills ?? {};
      config.skills.paths = config.skills.paths ?? [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
}) satisfies Plugin;
```

- [ ] **Step 2: Install type dep and verify typecheck**

Run: `npm install`
Expected: `node_modules/` created, `@opencode-ai/plugin` installed.

Run: `npx tsc --noEmit`
Expected: PASS (no output, exit 0).

- [ ] **Step 3: Commit**

```bash
git add .opencode/plugins/swift-skills.ts
git commit -m "Add swift-skills.ts plugin entry (config hook)"
```

---

### Task 4: Create the catalog manifest

**Files:**
- Create: `scripts/catalog.json`

- [ ] **Step 1: Create scripts/ directory and catalog.json**

```json
[
  { "name": "swiftui-pro", "category": "swiftui", "repo": "https://github.com/twostraws/SwiftUI-Agent-Skill", "subdir": "." },
  { "name": "swiftui-ui-patterns", "category": "swiftui", "repo": "https://github.com/Dimillian/Skills", "subdir": "swiftui-ui-patterns" },
  { "name": "swiftui-design-principles", "category": "swiftui", "repo": "https://github.com/arjitj2/swiftui-design-principles", "subdir": "." },
  { "name": "swiftui-view-refactor", "category": "swiftui", "repo": "https://github.com/Dimillian/Skills", "subdir": "swiftui-view-refactor" },
  { "name": "swiftdata-pro", "category": "swiftdata", "repo": "https://github.com/twostraws/SwiftData-Agent-Skill", "subdir": "." },
  { "name": "swiftdata-expert", "category": "swiftdata", "repo": "https://github.com/vanab/swiftdata-agent-skill", "subdir": "." },
  { "name": "swift-concurrency-pro", "category": "concurrency", "repo": "https://github.com/twostraws/Swift-Concurrency-Agent-Skill", "subdir": "." },
  { "name": "swift-concurrency-expert-dimillian", "category": "concurrency", "repo": "https://github.com/Dimillian/Skills", "subdir": "swift-concurrency-expert" },
  { "name": "swift-concurrency-expert", "category": "concurrency", "repo": "https://github.com/AvdLee/Swift-Concurrency-Agent-Skill", "subdir": "." },
  { "name": "swift-testing-pro", "category": "testing", "repo": "https://github.com/twostraws/Swift-Testing-Agent-Skill", "subdir": "." },
  { "name": "swift-testing-agent-skill", "category": "testing", "repo": "https://github.com/bocato/swift-testing-agent-skill", "subdir": "." },
  { "name": "swift-testing-expert", "category": "testing", "repo": "https://github.com/AvdLee/Swift-Testing-Agent-Skill", "subdir": "." },
  { "name": "swift-api-design-guidelines", "category": "language", "repo": "https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill", "subdir": "." },
  { "name": "swift-formatstyle", "category": "language", "repo": "https://github.com/n0an/Swift-FormatStyle-Agent-Skill", "subdir": "." },
  { "name": "ios-accessibility", "category": "accessibility", "repo": "https://github.com/dadederk/iOS-Accessibility-Agent-Skill", "subdir": "." },
  { "name": "swift-accessibility", "category": "accessibility", "repo": "https://github.com/PasqualeVittoriosi/swift-accessibility-skill", "subdir": "." },
  { "name": "apple-accessibility", "category": "accessibility", "repo": "https://github.com/rgmez/apple-accessibility-skills", "subdir": "." },
  { "name": "app-intents", "category": "app-intents", "repo": "https://github.com/n0an/App-Intents-Agent-Skill", "subdir": "." },
  { "name": "app-store-connect-cli", "category": "app-store", "repo": "https://github.com/rudrankriyam/app-store-connect-cli-skills", "subdir": "." },
  { "name": "app-store-changelog", "category": "app-store", "repo": "https://github.com/Dimillian/Skills", "subdir": "app-store-changelog" },
  { "name": "app-store-aso-optimization", "category": "app-store", "repo": "https://github.com/timbroddin/app-store-aso-skill", "subdir": "." },
  { "name": "app-store-review", "category": "app-store", "repo": "https://github.com/3paws-ai/mobile-ai-skills", "subdir": "skills/appstore-review" },
  { "name": "swift-architecture", "category": "architecture", "repo": "https://github.com/efremidze/swift-architecture-skill", "subdir": "." },
  { "name": "core-data-expert", "category": "core-data", "repo": "https://github.com/AvdLee/Core-Data-Agent-Skill", "subdir": "." },
  { "name": "swift-focusengine-pro", "category": "focus", "repo": "https://github.com/mhaviv/Swift-FocusEngine-Agent-Skill", "subdir": "." },
  { "name": "swiftui-performance-audit", "category": "performance", "repo": "https://github.com/Dimillian/Skills", "subdir": "swiftui-performance-audit" },
  { "name": "swift-security-expert", "category": "security", "repo": "https://github.com/ivan-magda/swift-security-skill", "subdir": "." },
  { "name": "ios-code-audit", "category": "audit", "repo": "https://github.com/jazzychad/ios-code-audit", "subdir": "." },
  { "name": "ios-simulator", "category": "tools", "repo": "https://github.com/conorluddy/ios-simulator-skill", "subdir": "." },
  { "name": "figma-to-swiftui", "category": "tools", "repo": "https://github.com/daetojemax/figma-to-swiftui-skill", "subdir": "." },
  { "name": "writing-for-interfaces", "category": "ui", "repo": "https://github.com/andrewgleave/skills", "subdir": "writing-for-interfaces" }
]
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -m json.tool scripts/catalog.json > /dev/null`
Expected: PASS (no output, exit 0).

- [ ] **Step 3: Commit**

```bash
git add scripts/catalog.json
git commit -m "Add catalog.json with 31 skill entries"
```

---

### Task 5: Create the sync script

**Files:**
- Create: `scripts/sync.sh`

- [ ] **Step 1: Create sync.sh**

```bash
#!/usr/bin/env bash
# Sync vendored skills from upstream repos per scripts/catalog.json.
# Idempotent: rm -rf each target before copying. Does not auto-commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG="$SCRIPT_DIR/catalog.json"
SKILLS_DIR="$SCRIPT_DIR/../skills"

# Resolve repo basename for clone dir naming.
repo_basename() {
  local url="$1"
  local name="${url##*/}"
  name="${name%.git}"
  printf '%s' "$name"
}

# Validate catalog.
if [[ ! -f "$CATALOG" ]]; then
  echo "ERROR: catalog.json not found at $CATALOG" >&2
  exit 1
fi
if ! python3 -m json.tool "$CATALOG" >/dev/null 2>&1; then
  echo "ERROR: catalog.json is not valid JSON" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

declare -A CLONED

synced=0
skipped=0
failed=0

# Read catalog entries via python (jq not guaranteed).
mapfile -t ENTRIES < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    for e in json.load(f):
        print(f"{e[\"name\"]}\t{e[\"category\"]}\t{e[\"repo\"]}\t{e[\"subdir\"]}")
' "$CATALOG")

for line in "${ENTRIES[@]}"; do
  IFS=$'\t' read -r name category repo subdir <<<"$line"
  base="$(repo_basename "$repo")"

  # Clone once per repo.
  if [[ -z "${CLONED[$repo]:-}" ]]; then
    echo "Cloning $repo ..."
    if git clone --depth 1 "$repo" "$TMPDIR/$base" 2>/dev/null; then
      CLONED[$repo]="$TMPDIR/$base"
    else
      echo "  WARN: clone failed for $repo, skipping $name" >&2
      failed=$((failed + 1))
      continue
    fi
  fi

  src="${CLONED[$repo]}"
  if [[ "$subdir" != "." ]]; then
    src="$src/$subdir"
  fi

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  WARN: no SKILL.md in $src, skipping $name" >&2
    skipped=$((skipped + 1))
    continue
  fi

  target="$SKILLS_DIR/$category/$name"
  mkdir -p "$target"
  rm -rf "${target:?}/"*
  cp -R "$src/." "$target/"

  # Warn if frontmatter name missing.
  if ! head -10 "$target/SKILL.md" | grep -q '^name:'; then
    echo "  WARN: $name SKILL.md missing frontmatter name field" >&2
  fi

  echo "  synced: $category/$name"
  synced=$((synced + 1))
done

echo ""
echo "Sync complete: $synced synced, $skipped skipped, $failed failed."
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/sync.sh`
Expected: PASS (no output).

- [ ] **Step 3: Commit**

```bash
git add scripts/sync.sh
git commit -m "Add sync.sh to vendor skills from upstream repos"
```

---

### Task 6: Run sync and vendor all skills

**Files:**
- Create: `skills/<category>/<name>/` (31 directories)

- [ ] **Step 1: Run the sync script**

Run: `./scripts/sync.sh`
Expected: Output listing "synced" for most entries; some may warn/skip if upstreams have moved. Aim: 31 synced, 0 failed.

- [ ] **Step 2: Verify skill count**

Run: `find skills -name SKILL.md | wc -l`
Expected: `31` (or close — note any failures).

- [ ] **Step 3: Verify directory structure**

Run: `find skills -name SKILL.md | sort`
Expected: 31 paths matching `skills/<category>/<name>/SKILL.md`.

- [ ] **Step 4: Verify idempotency**

Run: `./scripts/sync.sh && git status --porcelain skills/`
Expected: empty (no changes after re-sync).

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "Vendor 31 Swift skills from upstream repos"
```

---

### Task 7: Update .gitignore for sync artifacts

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Read current .gitignore**

Run: `cat .gitignore`
Expected: `.DS_Store`.

- [ ] **Step 2: Add node_modules and temp artifacts**

Append to `.gitignore`:
```
node_modules/
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "Ignore node_modules from plugin type dep install"
```

---

### Task 8: Add INSTALL.md for opencode users

**Files:**
- Create: `.opencode/INSTALL.md`

- [ ] **Step 1: Create INSTALL.md**

```markdown
# Installing Swift-Agent-Skills for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add swift-agent-skills to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all bundled Swift skills automatically.

Verify by asking: "List your available Swift skills"

## Pinning a version

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git#v0.1.0"]
}
```

## Alternative: local clone

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
```

OpenCode auto-loads `*.ts` files in `~/.config/opencode/plugins/`.

## Alternative: skills.paths only (no plugin code)

```json
{
  "skills": { "paths": ["./Swift-Agent-Skills/skills"] }
}
```

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load swiftui-pro
```

## Updating

Re-run the install or clear OpenCode's package cache. Swift skills are static;
updating requires the maintainer to run `scripts/sync.sh` and publish a new
version.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i swift`
2. Verify the plugin line in your `opencode.json`
3. Make sure you're running a recent version of OpenCode

### Skills not found

1. Use `skill` tool to list what's discovered
2. Check that the plugin is loading (see above)
```

- [ ] **Step 2: Commit**

```bash
git add .opencode/INSTALL.md
git commit -m "Add INSTALL.md for opencode users"
```

---

### Task 9: Update README with plugin usage section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README around the License section**

Run: read README.md, locate the `## License` heading (line ~172).

- [ ] **Step 2: Insert new section before ## License**

Insert this section immediately before `## License`:

```markdown
## Use as an opencode plugin

This repository is also packaged as an opencode plugin that bundles all listed Swift skills and auto-registers them. One-line install:

```json
{
  "plugin": ["swift-agent-skills@git+https://github.com/SameTrouble/Swift-Agent-Skills.git"]
}
```

Restart OpenCode, then use the `skill` tool to list or load any of the bundled skills (e.g. `swiftui-pro`, `swiftdata-pro`, `swift-concurrency-pro`). Skills trigger automatically when their description matches your task.

### Alternative install methods

**Local clone (auto-discovery):**

```bash
git clone https://github.com/SameTrouble/Swift-Agent-Skills ~/.config/opencode/plugins/Swift-Agent-Skills
```

**Static skills only (no plugin code):**

```json
{
  "skills": { "paths": ["./Swift-Agent-Skills/skills"] }
}
```

### Syncing skills (maintainers)

Vendored skills live under `skills/<category>/<name>/`. To refresh from upstream repos:

```bash
./scripts/sync.sh
```

This reads `scripts/catalog.json`, re-clones each upstream, and copies skill files into `skills/`. Review `git diff` before committing.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "Add 'Use as an opencode plugin' section to README"
```

---

### Task 10: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Verify TS typecheck passes**

Run: `npx tsc --noEmit`
Expected: PASS (no output, exit 0).

- [ ] **Step 2: Verify catalog JSON is valid**

Run: `python3 -m json.tool scripts/catalog.json > /dev/null`
Expected: PASS.

- [ ] **Step 3: Verify all catalog entries have a vendored SKILL.md**

Run:
```bash
python3 -c '
import json, os
with open("scripts/catalog.json") as f:
    for e in json.load(f):
        p = os.path.join("skills", e["category"], e["name"], "SKILL.md")
        if not os.path.exists(p):
            print(f"MISSING: {p}")
        else:
            print(f"OK: {p}")
'
```
Expected: 31 `OK:` lines, no `MISSING:`.

- [ ] **Step 4: Verify sync script idempotency**

Run: `./scripts/sync.sh && git status --porcelain`
Expected: empty output (no changes after re-sync).

- [ ] **Step 5: Verify plugin structure**

Run: `ls .opencode/plugins/swift-skills.ts package.json scripts/catalog.json scripts/sync.sh`
Expected: all four files listed.

- [ ] **Step 6: Verify git working tree clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

## Self-Review

**Spec coverage:**
- ✅ TypeScript plugin entry with config hook — Task 3
- ✅ `skills/` vendored directory — Task 6
- ✅ `catalog.json` manifest — Task 4
- ✅ `sync.sh` sync script with idempotency, edge cases — Task 5
- ✅ `package.json` with name/main/type dep — Task 1
- ✅ GitHub-direct install + alternatives — Task 8 (INSTALL.md), Task 9 (README)
- ✅ README update with plugin section — Task 9
- ✅ Verification table — Task 10
- ✅ 16 category directories — implicit in catalog (Task 4) and produced by sync (Task 6)
- ✅ 31 catalog entries — Task 4

**Placeholder scan:** No TBD/TODO. All code blocks contain final content. The one inherent variable is sync.sh runtime success (network/upstream), handled by the script's warn-and-skip with explicit expected counts in Task 6.

**Type consistency:** `swift-skills.ts` uses `config.skills.paths` (matches opencode schema: `skills.paths` is an array of strings). `catalog.json` field names (`name`, `category`, `repo`, `subdir`) match sync.sh's python parser output columns and the spec's schema section. `package.json` `name` (`swift-agent-skills`) matches the plugin spec in INSTALL.md/README. `main` (`.opencode/plugins/swift-skills.ts`) matches the created file path.
