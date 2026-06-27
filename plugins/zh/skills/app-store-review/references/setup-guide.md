---
last_verified: "2026-03-30"
---

# appstore-review — 设置与使用指南

本指南帮助你将 `appstore-review` 技能接入 AI 编程代理，使其在项目中可靠运行。

---

## 1. 安装技能

### 选项 A：安装脚本

```bash
git clone https://github.com/3paws-ai/mobile-ai-skills.git
cd mobile-ai-skills
./scripts/install.sh appstore-review
```

此操作将技能复制到 `~/.claude/skills/appstore-review/`。

### 选项 B：手动复制

```bash
cp -R skills/appstore-review ~/.claude/skills/appstore-review
```

### 验证安装

安装后，确认以下文件存在：

```
~/.claude/skills/appstore-review/
  SKILL.md
  references/
    appstore-review-ref.md
    setup-guide.md
```

---

## 2. 在 CLAUDE.md 中注册技能

为了让 Claude Code 识别该技能，请将其添加到 `~/.claude/CLAUDE.md`（全局）或项目的 `CLAUDE.md` 中。在你的技能表中添加条目：

```markdown
## Skills

| Task | Skill to read |
|---|---|
| App Store review readiness audit | `~/.claude/skills/appstore-review/SKILL.md` |
```

这告诉代理在被调用时去哪里查找技能。

---

## 3. 可选：添加常设清单

如果你经常提交到 App Store，可以在 CLAUDE.md 中添加快速参考清单，让代理在非完整审计时也标记这些事项：

```markdown
## App Store Submission — Standing Checklist
Before any release, verify:
- [ ] All new APIs have Privacy Manifest entries (`PrivacyInfo.xcprivacy`)
- [ ] App Tracking Transparency prompt implemented if using IDFA
- [ ] No placeholder or Lorem Ipsum text anywhere in the UI
- [ ] All required device screenshots generated (6.9", 6.5", iPad if universal)
- [ ] Release notes written in plain language, user-benefit framing
- [ ] Version and build number bumped in both targets (app + extensions)
- [ ] TestFlight beta tested on a real device before submission
- [ ] App Review notes drafted if app has any login, special flows, or content
```

这是完整审计的轻量补充——审计是全面的，而清单是快速关卡。

---

## 4. 如何调用

在 Claude Code 中，从你的 iOS 项目目录运行：

```
/appstore-review
```

代理读取 `SKILL.md` 并系统性地检查你的项目——Swift 源码、Info.plist、entitlements、xcprivacy 清单、资源目录和项目配置。

**技能按顺序运行所有检查，无需提示。** 你不需要选择部分。它会检查所有内容并生成汇总。

---

## 5. 何时运行

| 时机 | 原因 |
|--------|-----|
| 每次 App Store 提交前 | 主要用例——完整的提交前审计 |
| TestFlight 构建前 | 在问题到达测试者之前捕获 |
| 添加订阅或 IAP 后 | 付费墙合规检查细致且容易遗漏 |
| 更新隐私敏感 API 后 | 隐私清单声明必须与实际使用匹配 |
| 重大依赖更新后 | 第三方 SDK 可能引入新的隐私清单要求 |

---

## 6. 预期输出

技能将每项检查报告为 **PASS**、**WARN** 或 **FAIL**，并以汇总表结束：

```
## App Store Review Audit — YourApp
Date: 2026-03-30

### Results
| #   | Check              | Status | Notes                              |
|-----|--------------------|--------|------------------------------------|
| 1.1 | App Completeness   | PASS   | No placeholder text found          |
| 1.2 | Privacy Manifest   | WARN   | UserDefaults reason code missing   |
| 1.3 | Subscription IAP   | PASS   | All disclosures present            |
| ... | ...                | ...    | ...                                |

### Critical Issues (FAIL — must fix before submission)
- None

### Warnings (WARN — should fix, risk of rejection)
- 1.2: PrivacyInfo.xcprivacy declares UserDefaults but no reason code

### Recommendations
- Add reason code C617.1 for UserDefaults access
```

如果没有 FAIL 项：**"No blocking issues found. Ready for submission."**

---

## 7. 不适用于你应用的部分

技能会自适应你的项目：

- **没有订阅？** — IAP/付费墙检查报告 PASS（不适用）。技能在评估合规性之前检测 StoreKit 使用情况。
- **没有推送通知？** — 推送 entitlement 检查优雅跳过。
- **没有使用 IDFA？** — ATT 提示检查报告 PASS。

你无需配置运行哪些部分。

---

## 8. 保持技能最新

Apple 在以下地址发布执行截止日期：
`https://developer.apple.com/news/upcoming-requirements/`

参考文件（`references/appstore-review-ref.md`）编目了约 60 个来源 URL 及 `last_verified` 日期。该文件第 8 节跟踪 2024-2026 年的时效性要求。

如果你发现新要求或失效 URL：
- 更新参考文件
- 递增 `SKILL.md` frontmatter 中的版本号
- 更新 `last_verified`
- 考虑将修复贡献回仓库
