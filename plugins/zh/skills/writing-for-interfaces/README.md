# 为界面而写技能

## 安装

```bash
npx skills add andrewgleave/skills --skill writing-for-interfaces --global
```

## 示例提示词

```text
/writing-for-interfaces 审查并评估所有界面文案的清晰度、目的和一致性。
```

## 技能结构

本仓库遵循 **Agent Skills** 开放标准。每个技能自包含，拥有自己的逻辑、工作流和参考资料。

```text
writing-for-interfaces/
├── SKILL.md              — 核心指令、原则与语调/语气指引
├── references/
│   └── patterns.md       — 常见界面模式的详细指引
└── README.md
```

## 工作原理

激活后，代理应用一个以语调为先的工作流：

1. **确立语调**：在项目文件中搜索现有语调定义（`CLAUDE.md / AGENTS.md`、风格指南、设计文档）。如果没有，或现有文案不一致，引导用户定义一个——产品做什么、为谁服务、在哪里使用、哪些性格特质定义它。确立且一致的语调是所有文案决策的基础。
2. **评估请求**：判断任务是写新文案、审查、重写还是术语工作，并识别适用哪些界面模式。
3. **应用语调与原则**：检查文案听起来是否符合定义的语调。根据情境调高或调低语气特质，再应用核心原则。
4. **评估**：查阅模式参考，获取针对结构、语气和常见陷阱的情境化指引。
5. **应用修改**：内联重写现有文案或从零起草。展示 原文 → 改写，附上关联到语调与原则的简短理由。优先处理让用户困惑或受阻的修改，再做润色。
6. **更新术语参考**：标记术语漂移并建议术语表条目，保持界面内语调与措辞一致。用户应能审查修改并批准或拒绝。

## 来源

许多原则提炼自 Apple 的界面写作指引，并推广至更广泛的产品界面：

- [**Human Interface Guidelines** — Writing](https://developer.apple.com/design/human-interface-guidelines/writing/)
- [**Human Interface Guidelines** — Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts/)
- [**Human Interface Guidelines** — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
- [**WWDC 2019** — Writing Great Accessibility Labels](https://developer.apple.com/videos/play/wwdc2019/254/)
- [**WWDC 2022** — Writing for Interfaces](https://developer.apple.com/videos/play/wwdc2022/10037/)
- [**WWDC 2024** — Adding Personality to Your App Through UX Writing](https://developer.apple.com/videos/play/wwdc2024/10140/)
- [**WWDC 2025** — Make a Big Impact with Small Writing Changes](https://developer.apple.com/videos/play/wwdc2025/404/)
- [**Apple Style Guide**](https://help.apple.com/applestyleguide/)
