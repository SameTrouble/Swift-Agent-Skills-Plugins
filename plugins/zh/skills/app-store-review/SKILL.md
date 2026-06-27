---
name: appstore-review
version: "1.1.0"
description: >
  iOS 应用的 App Store 审核就绪性审计。扫描代码库、entitlements、
  Info.plist、隐私清单、付费墙/订阅 UI 和元数据，查找任何可能在
  App Store 审核期间触发警告或拒绝的内容。在准备提交时显式调用。
  请勿自动触发。
author: 3 Paws AI Studio
license: MIT
agents:
  - claude-code
tags:
  - ios
  - app-store
  - review
  - submission
  - privacy-manifest
  - storekit
trigger: manual
last_verified: "2026-03-30"
---

# App Store 审核就绪性审计

## 目的
在提交之前，捕获每一个可能导致 App Store 警告或拒绝的问题。此技能运行双轨审计：**代码/entitlements** 和**提交元数据**。按拒绝频率排序（最高风险优先），依据 Apple 2024 年透明度报告数据。

**参考文件**：`references/appstore-review-ref.md` 包含支持每项检查的 Apple 文档、WWDC 会议和社区资源的完整目录。

---

## 如何运行审计

被调用时，按顺序执行下方每个部分。对于每项检查：
1. 检查项目中相关的文件/配置
2. 报告 **PASS**、**WARN** 或 **FAIL**，并附一行说明
3. 最后，生成所有结果的汇总表

请勿跳过任何部分。请勿询问用户要运行哪些部分——全部运行。

---

## 轨道 1 — 代码与 Entitlements 审计

### 1.1 应用完整性（准则 2.1）— 第 1 大拒绝原因

此项占所有未解决拒绝的 40% 以上。

- [ ] 全新安装时应用可正常启动，不崩溃
- [ ] UI 中任何位置均无占位符或 Lorem Ipsum 文本（搜索所有 `.swift` 文件和资源目录）
- [ ] 无指示未完成工作的 TODO/FIXME/HACK 注释（对用户可见的）
- [ ] 所有导航路径均可正常使用——无死胡同页面或未实现的按钮
- [ ] 所有 URL（支持、隐私政策、条款）均有效且能正确加载
- [ ] 登录/引导流程完整无错误
- [ ] 深链接和通用链接正确解析（如适用）
- [ ] 应用在飞行模式下可正常工作或能优雅处理无网络状态

### 1.2 隐私清单（ITMS-91053 / ITMS-91061）— 自动化拒绝

自 2024 年 5 月 1 日起强制执行。缺失声明会在人工审核前即被拒绝。

- [ ] 应用 target 中存在 `PrivacyInfo.xcprivacy`
- [ ] 所有五个 Required Reason API 类别均已检查使用情况：
  - `NSPrivacyAccessedAPICategoryFileTimestamp` — `creationDate`、`modificationDate`、`stat()`
  - `NSPrivacyAccessedAPICategorySystemBootTime` — `systemUptime`、`mach_absolute_time()`
  - `NSPrivacyAccessedAPICategoryDiskSpace` — `volumeAvailableCapacityKey`、`NSFileSystemFreeSize`
  - `NSPrivacyAccessedAPICategoryActiveKeyboards` — `UITextInputMode.activeInputModes`
  - `NSPrivacyAccessedAPICategoryUserDefaults` — `UserDefaults`
- [ ] 每个使用中的 Required Reason API 都有匹配的声明及已批准的原因代码
- [ ] `NSPrivacyCollectedDataTypes` 准确反映应用收集的所有数据
- [ ] `NSPrivacyTracking` 设置正确（仅在使用 IDFA/ATT 时为 `true`）
- [ ] Apple 名单上的第三方 SDK 包含各自的隐私清单
- [ ] 通过 Xcode Organizer 生成隐私报告以交叉核对声明

### 1.3 订阅与 IAP 合规性（准则 3.1.1 / 3.1.2）

订阅应用第二大高风险领域。

**付费墙 UI — 必需披露（准则 3.1.2(c) + Schedule 2 §3.8(b)）：**
- [ ] 显示订阅名称和时长
- [ ] 完整续订价格是**最显眼的定价元素**（非月度等价金额）
- [ ] 显示免费试用时长和试用后价格（如适用）
- [ ] 存在可点击的使用条款链接且功能正常
- [ ] 存在可点击的隐私政策链接且功能正常
- [ ] "恢复购买"按钮/机制可访问（准则 3.1.1）
- [ ] 无暗黑模式：无虚假紧迫感、不隐藏年度定价、无未明确披露的预选昂贵选项
- [ ] 存在订阅自动续订说明（例如"订阅将自动续订，除非在当前周期结束前至少 24 小时取消"）
- [ ] 存在取消/管理说明（或使用 `AppStore.showManageSubscriptions(in:)`）

**注意：** 仅应用内披露是不够的。第 2.1 部分检查使用条款和隐私政策链接是否也出现在 App Store 描述或 App Store Connect 的 EULA 字段中——Apple 要求两者兼备。

**StoreKit 实现：**
- [ ] 使用 StoreKit 2（非已弃用的 StoreKit 1 / `SKPaymentQueue`）
- [ ] 交易经过验证（JWS 验证或 RevenueCat 处理）
- [ ] 购买、恢复和订阅到期后 entitlements 正确更新
- [ ] 已实现宽限期处理（如在 App Store Connect 中启用）
- [ ] 沙盒购买在应用中正常工作

**App Store Connect 配置：**
- [ ] IAP 产品处于"Ready to Submit"或"Approved"状态
- [ ] 每个 IAP 均已上传审核截图
- [ ] 订阅组配置正确
- [ ] 已为所有必需的地区设置定价

### 1.4 隐私与数据处理（准则 5.1）

- [ ] App Store Connect 中已设置隐私政策 URL 且可访问
- [ ] 隐私政策 URL 也可从应用内访问
- [ ] App Store Connect 中的应用隐私营养标签与实际数据收集相符
- [ ] 如果应用使用 IDFA：已实现 ATT 提示（`ATTrackingManager.requestTrackingAuthorization`）
- [ ] 如果应用使用第三方 AI：已获得数据共享的明确同意（准则 5.1.2(i)，2025 年 11 月起执行）
- [ ] 如果应用支持账户创建，则提供账户删除选项（准则 5.1.1(v)）

### 1.5 App Transport Security

- [ ] Info.plist 中无 `NSAllowsArbitraryLoads = YES`（除非有正当理由）
- [ ] 所有网络连接使用 HTTPS / TLS 1.2+
- [ ] 如果通过 `NSExceptionDomains` 存在域名例外，每个都有文档说明的正当理由

### 1.6 出口合规

- [ ] Info.plist 中已设置 `ITSAppUsesNonExemptEncryption`
- [ ] 如果仅使用标准 HTTPS（URLSession），值为 `NO`（豁免）
- [ ] 如果使用自定义加密，值为 `YES` 且存在 CCATS/ERN 文档

### 1.7 Entitlements 与能力

- [ ] 仅存在必需的 entitlements（无未使用的功能）
- [ ] App ID 是显式的（非通配符）— IAP 所必需
- [ ] 在 Signing & Capabilities 中已启用 In-App Purchase 能力
- [ ] 仅在实现推送时才存在推送通知 entitlement
- [ ] 除非使用 Apple Pay，否则无 `com.apple.developer.in-app-payments`（这不是 IAP entitlement）

### 1.8 代码质量标记

- [ ] 生产代码中无 `print()` 语句（使用 `os.Logger`）
- [ ] 测试外部无强制解包（`!`）
- [ ] 源码中无硬编码的 API 密钥、机密或令牌
- [ ] 无对内部/调试 URL、测试服务器或预发布端点的引用
- [ ] 无在发布构建中暴露测试 UI 的 `#if DEBUG` 代码块

---

## 轨道 2 — 提交元数据清单

### 2.1 App Store Connect 元数据

- [ ] 应用名称：≤30 个字符，无关键词堆砌
- [ ] 副标题：≤30 个字符
- [ ] 描述：首行有钩子，强调利益而非功能，无占位符文本
- [ ] 关键词：≤100 个字符，逗号分隔，逗号后无空格，不与应用名称词重复
- [ ] 宣传文本：已设置（无需新版本即可编辑）
- [ ] 新功能：用通俗语言撰写，以用户利益为导向
- [ ] 支持 URL：已设置且可正常加载
- [ ] 隐私政策 URL：已设置且可正常加载
- [ ] 如果应用有订阅：应用描述中包含使用条款（EULA）链接，或在 App Store Connect 中设置自定义 EULA
- [ ] 如果应用有订阅：应用描述中包含隐私政策链接
- [ ] 如果应用有订阅：应用描述中包含自动续订说明（价格、时长、取消方式）
- [ ] 版权：已设置当前年份和正确的实体名称
- [ ] 主类别和可选的次类别设置得当

### 2.2 截图与预览

- [ ] 至少有一组 6.5" 或 6.9" iPhone 截图
- [ ] 如果是通用应用，提供 iPad 截图
- [ ] 截图为 JPEG 或 PNG 格式
- [ ] 无占位符或明显伪造的截图
- [ ] 应用预览 ≤30 秒，H.264 或 ProRes 422（如使用）
- [ ] 截图展示真实应用 UI（无误导性）

### 2.3 应用图标

- [ ] 提供 1024x1024 App Store 图标
- [ ] 图标不含透明度或 Alpha 通道
- [ ] 图标不是其他应用图标的副本
- [ ] 应用内图标与 App Store 图标一致

### 2.4 版本与构建号

- [ ] 版本号适当递增（语义化版本）
- [ ] 构建号较上次上传有所递增
- [ ] 应用 target 和扩展 target（如有）的版本/构建号一致
- [ ] 使用当前必需的 SDK 版本构建

### 2.5 年龄分级

- [ ] 在 App Store Connect 中完成年龄分级问卷
- [ ] 分级反映实际内容（特别是 AI/聊天机器人内容，如适用）
- [ ] 如果扩展年龄分级适用（13+/16+/18+）：已在 2026 年 1 月 31 日截止日期前更新回复

### 2.6 审核备注

- [ ] 如果应用有登录：在审核备注中提供演示凭据
- [ ] 如果应用有特殊流程（订阅、硬件功能）：提供说明
- [ ] 如果应用使用端侧 AI：注明设备/操作系统要求
- [ ] 如果应用有订阅：审核备注说明应用内订阅披露的位置（付费墙位置、设置等）
- [ ] 审核员联系方式是最新的

---

## 输出格式

运行所有检查后，生成以下汇总：

```
## App Store Review Audit — [App Name]
Date: [YYYY-MM-DD]

### Results
| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1.1 | App Completeness | PASS/WARN/FAIL | ... |
| 1.2 | Privacy Manifest | PASS/WARN/FAIL | ... |
| ... | ... | ... | ... |

### Critical Issues (FAIL — must fix before submission)
- [list]

### Warnings (WARN — should fix, risk of rejection)
- [list]

### Recommendations
- [list]
```

如果没有 FAIL 项，声明："No blocking issues found. Ready for submission."

---

## 当要求发生变化时

Apple 在以下地址发布执行截止日期：
`https://developer.apple.com/news/upcoming-requirements/`

如果用户提到特定截止日期或新要求，请对照 `references/appstore-review-ref.md` 第 8 节查看最新跟踪的变更。
