---
last_verified: "2026-03-30"
---

# iOS App Store 审计技能的权威参考

**构建一个面向 iOS 17+ SwiftUI 应用（搭配 StoreKit 2 订阅）的稳健 App Store 审核就绪性技能，需要锚定约 60 份 Apple 官方文档和少量经过实战检验的社区资源。** 随着强制隐私清单、StoreKit 1 的弃用以及欧盟 DMA 合规要求的实施，2024 年的格局发生了显著变化——而 2025–2026 年还将有更多变化，包括扩展的年龄分级和新的 SDK 构建要求。本报告按审计领域分类编目了应接入技能的每份参考，包含确切 URL、来源分类和变更日期标记。

---

## 1. 锚定整个技能的核心 Apple 准则

位于 `https://developer.apple.com/app-store/review/guidelines/` 的 **App Store Review Guidelines** 是最关键的单一文档。对于 IAP/订阅应用，触发大多数拒绝的条款是：

- **第 3.1.1 节（应用内购买）** — 要求所有数字商品使用 Apple IAP；强制要求"恢复购买"机制
- **第 3.1.2 节（订阅）** — 子节 (a) 允许的用途、(b) 升级/降级、(c) 订阅信息披露、(d) 第三方内容规则
- **第 3.1.3 节（外部链接）** — 2024 年为遵守美国法院裁决而更新（StoreKit External Purchase Link Entitlement）
- **第 2.1 节（应用完整性）** — 根据 Apple 自身数据，占所有未解决拒绝的 **40% 以上**
- **第 5.1 节（隐私）** — 数据收集、使用、共享；2024 年新增的子节 5.1.2(i) 要求第三方 AI 数据共享须获得明确同意

还应参考两个配套准则中心。位于 `https://developer.apple.com/distribute/app-review/` 的 **App Review 准备页面**汇总了常见问题和提交提示。Apple 位于 `https://developer.apple.com/news/upcoming-requirements/` 的 **Upcoming Requirements 页面**发布新执行要求的截止日期——你的技能应定期检查此页面以保持最新。

位于 `https://developer.apple.com/design/human-interface-guidelines/` 的 **Human Interface Guidelines** 包含专门的 **In-App Purchase 部分**，位于 `https://developer.apple.com/design/human-interface-guidelines/in-app-purchase`，涵盖付费墙 UI 模式、SubscriptionStoreView 使用和 SwiftUI 中的订阅推销。另有独立的**自动续订订阅设计页面**，位于 `https://developer.apple.com/design/human-interface-guidelines/in-app-purchase/overview/auto-renewable-subscriptions/`。

位于 `https://developer.apple.com/help/app-store-connect/` 的 **App Store Connect Help** 是每个元数据字段、提交流程和配置步骤的操作参考。关键子部分包括位于 `https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/` 的 **Required, Localizable, and Editable Properties 参考**和位于 `https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses` 的 **App and Submission Statuses 参考**。

| 资源 | URL | 来源 |
|----------|-----|--------|
| App Store Review Guidelines | `https://developer.apple.com/app-store/review/guidelines/` | Apple 官方 |
| App Review 准备 | `https://developer.apple.com/distribute/app-review/` | Apple 官方 |
| Upcoming Requirements | `https://developer.apple.com/news/upcoming-requirements/` | Apple 官方 |
| Human Interface Guidelines | `https://developer.apple.com/design/human-interface-guidelines/` | Apple 官方 |
| HIG：In-App Purchase | `https://developer.apple.com/design/human-interface-guidelines/in-app-purchase` | Apple 官方 |
| App Store Connect Help | `https://developer.apple.com/help/app-store-connect/` | Apple 官方 |
| Required Properties 参考 | `https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/` | Apple 官方 |

---

## 2. StoreKit 2 和订阅专用参考

### StoreKit 2 框架文档

位于 `https://developer.apple.com/storekit/` 的 **StoreKit 登录页面**是现代入口，涵盖 SwiftUI 视图（StoreView、ProductView、SubscriptionStoreView）、JWS 签名交易和 Swift 并发 API。**完整框架参考**位于 `https://developer.apple.com/documentation/storekit`，关键的**迁移决策指南**（"Choosing a StoreKit API"）位于 `https://developer.apple.com/documentation/storekit/choosing-a-storekit-api-for-in-app-purchases`。**警告：2024 年变更：** 原始 StoreKit API 在 WWDC24 上于 iOS 18 中正式弃用——你的技能应标记任何剩余的 StoreKit 1 用法。

对于服务端集成，位于 `https://developer.apple.com/documentation/appstoreserverapi` 的 **App Store Server API** 用 12 个现代端点替代了已弃用的 `verifyReceipt` 端点，用于交易历史、订阅状态和退款处理。位于 `https://developer.apple.com/documentation/AppStoreServerNotifications/App-Store-Server-Notifications-V2` 的 **Server Notifications V2** 提供 JWS 签名的事件负载，包含 20 多种事件类型。

### 必需的订阅披露（高拒绝风险领域）

Apple 位于 `https://developer.apple.com/app-store/subscriptions/` 的**自动续订订阅页面**是最重要的订阅专用参考。根据准则 3.1.2(c) 和 Apple Developer Program License Agreement 的 Schedule 2 第 3.8(b) 节，订阅注册页面**必须**包含：

- 订阅名称和时长，并描述内容/服务
- **完整续订价格作为最显眼的定价元素显示**，按货币本地化
- 免费试用时长和试用后价格（如适用）
- 可点击的使用条款和隐私政策链接
- "恢复购买"机制（按钮或等效方式）

RevenueCat 对必需披露语言的分析位于 `https://www.revenuecat.com/blog/engineering/schedule-2-section-3-8-b/`。

### 在所有三个环境中测试 IAP

你的技能应验证**三个不同层级**的测试。Apple 的主测试指南位于 `https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox`：

| 测试环境 | 文档 URL | 关键详情 |
|------------------|-------------------|-------------|
| Xcode StoreKit 测试（本地） | `https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode` | 使用 StoreKit Configuration 文件；无需网络；完全控制交易 |
| 沙盒（服务器连接） | `https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox` | 服务器到服务器测试；最多 10,000 个沙盒账户 |
| TestFlight | `https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/` | 使用沙盒环境；1 个月订阅 = 24 小时续订；6 次续订后自动取消 |

App Store Connect 中的沙盒账户管理文档位于 `https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/` 和 `https://developer.apple.com/help/app-store-connect/test-in-app-purchases/manage-sandbox-apple-account-settings/`。

### App Store Connect 中的 IAP 和订阅配置

| 任务 | URL |
|------|-----|
| 配置 IAP 概览 | `https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/` |
| 创建消耗型/非消耗型 IAP | `https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/` |
| 提供自动续订订阅 | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/` |
| 设置引导优惠 | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/` |
| 设置促销优惠 | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-promotional-offers-for-auto-renewable-subscriptions/` |
| 设置赢回优惠（2024 年新增） | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-win-back-offers/` |
| 管理订阅定价 | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/` |
| 启用计费宽限期 | `https://developer.apple.com/help/app-store-connect/manage-subscriptions/enable-billing-grace-period-for-auto-renewable-subscriptions/` |
| 生成 IAP 密钥（用于 Server API JWT） | `https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/generate-keys-for-in-app-purchases/` |
| 在 App Store 推广 IAP | `https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/promote-in-app-purchases` |

每个提交审核的 IAP 都需要一张**审核截图**（展示购买在应用内的上下文）和**审核备注**。被推广的 IAP 还需要一张 **1024x1024 推广图片**。

订阅管理深链接 API——`AppStore.showManageSubscriptions(in:)`，文档位于 `https://developer.apple.com/documentation/storekit/appstore/3803198-showmanagesubscriptions`——强烈建议用于 iOS 15+ 的应用内订阅管理。

---

## 3. 代码和 entitlements 审计参考

### 应用内购买能力和 entitlements

你的技能需要注意一个关键细节：**In-App Purchase 不受 entitlement 键控制**。不存在 `com.apple.developer.in-app-purchase` entitlement。IAP 仅需要一个**显式（非通配符）App ID**，通过在 Xcode 的 Signing & Capabilities 标签页添加"In-App Purchase"能力来启用。常被混淆的 `com.apple.developer.in-app-payments` entitlement 是用于通过 PassKit 的 **Apple Pay / Merchant ID**，而非 StoreKit IAP。这一区别在 Apple Developer Forums 的帖子 `https://developer.apple.com/forums/thread/738035` 中得到确认。

通用 entitlements 文档位于 `https://developer.apple.com/documentation/bundleresources/entitlements`，能力概览位于 `https://developer.apple.com/help/account/capabilities/capabilities-overview/`。**2024 年新增：** 位于 `https://developer.apple.com/support/storekit-external-entitlement-us/` 的 **StoreKit External Purchase Link Entitlement**（仅限美国）是针对在准则 3.1.3(a) 下提供外部购买链接的应用的新 entitlement。

### 隐私清单 — 2024 年最具影响力的执行变更

**自 2024 年 5 月 1 日起强制执行。** 上传到 App Store Connect 但没有正确 `PrivacyInfo.xcprivacy` 声明的应用会收到 **ITMS-91053** 拒绝。截至 2025 年 2 月 12 日，Apple 名单上的第三方 SDK 也必须包含各自的隐私清单（ITMS-91061 拒绝）。这是自 App Tracking Transparency 以来最大的新合规要求。

| 资源 | URL | 备注 |
|----------|-----|-------|
| 隐私清单文件（主文档） | `https://developer.apple.com/documentation/bundleresources/privacy-manifest-files` | 主要参考 |
| 添加隐私清单 | `https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk` | 分步指南 |
| 描述 Required Reason API 的使用 | `https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api` | 5 个 API 类别 + 已批准原因的完整列表 |
| TN3183：添加 Required Reason API 条目 | `https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest` | 详细实现技术说明 |
| 第三方 SDK 要求 | `https://developer.apple.com/support/third-party-SDK-requirements/` | 需要清单 + 签名的 SDK 列表 |
| WWDC23：隐私清单入门 | `https://developer.apple.com/videos/play/wwdc2023/10060/` | 必看概览视频 |
| 执行公告（2024 年 5 月） | `https://developer.apple.com/news/?id=pvszzano` | 截止日期确认 |

你的技能必须检查的**五个 Required Reason API 类别**：

| 类别 | 键 | 常见 API |
|----------|-----|-------------|
| 文件时间戳 | `NSPrivacyAccessedAPICategoryFileTimestamp` | `creationDate`、`modificationDate`、`stat()`、`fstat()` |
| 系统启动时间 | `NSPrivacyAccessedAPICategorySystemBootTime` | `systemUptime`、`mach_absolute_time()` |
| 磁盘空间 | `NSPrivacyAccessedAPICategoryDiskSpace` | `volumeAvailableCapacityKey`、`NSFileSystemFreeSize` |
| 活动键盘 | `NSPrivacyAccessedAPICategoryActiveKeyboards` | `UITextInputMode.activeInputModes` |
| User Defaults | `NSPrivacyAccessedAPICategoryUserDefaults` | `UserDefaults`（几乎所有应用都使用此项） |

Xcode 15+ 将应用和第三方 SDK 的所有隐私清单聚合为**隐私报告 PDF**，可通过 Organizer > 右键点击归档 > "Generate Privacy Report" 访问。此报告有助于准确完成 App Store Connect 中的**应用隐私营养标签**。

### App Transport Security

ATS 对于所有链接到 iOS 9+ SDK 的应用默认启用，并通过 URLSession 要求所有 HTTP 连接使用 **TLS 1.2+**。主要参考位于 `https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity`，实用指南位于 `https://developer.apple.com/documentation/security/preventing-insecure-network-connections`。设置 `NSAllowsArbitraryLoads = YES` 会触发 App Review 审查并需要正当理由。通过 `NSExceptionDomains` 进行域名特定例外是首选方法。

---

## 4. 元数据和提交清单参考

### 截图和应用预览规格

现在每个主要设备类别只需**一张截图**（6.5"/6.9" iPhone 和 13" iPad）；所有其他尺寸自动缩放。每种设备尺寸最多 10 张截图（JPEG/PNG 格式），每种设备最多 3 个应用预览（最长 30 秒，H.264 或 ProRes 422）。

| 资源 | URL |
|----------|-----|
| 截图规格 | `https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/` |
| 应用预览规格 | `https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/` |
| 上传指南 | `https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/` |
| 应用预览最佳实践 | `https://developer.apple.com/app-store/app-previews/` |

### 元数据字段规则

| 字段 | 限制 | 无需新版本即可编辑？ |
|-------|-------|-------------------------------|
| 应用名称 | 30 个字符 | 否 |
| 副标题 | 30 个字符 | 否 |
| 描述 | 4,000 个字符 | 否 |
| 宣传文本 | 170 个字符 | **是** |
| 关键词 | 100 个字符（逗号分隔，逗号后无空格） | 否 |
| 新功能 | 4,000 个字符 | 每版本 |
| 支持 URL | 必填，必须可用 | 是 |
| 营销 URL | 可选 | 是 |
| 隐私政策 URL | **所有应用必填** | 是 |
| 版权 | 必填（年份 + 实体） | 每版本 |

关键词优化指南位于 `https://developer.apple.com/app-store/search/`。产品页面创建指南位于 `https://developer.apple.com/app-store/product-page/`。

### 隐私营养标签、年龄分级和出口合规

**隐私营养标签**（在 App Store Connect 中声明，显示在产品页面上）文档位于 `https://developer.apple.com/app-store/app-privacy-details/`，管理指南位于 `https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/`。这些与隐私清单不同，但受其信息支撑。

**年龄分级**通过问卷设置，位于 `https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/`。**2025-2026 年变更：** Apple 扩展了系统，在现有的 4+ 和 9+ 之外增加了 **13+、16+ 和 18+** 分级，新增问题涵盖应用内控制、AI/聊天机器人内容以及医疗/健康话题。开发者须在 **2026 年 1 月 31 日**前做出回应。

**出口合规**文档位于 `https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/`。大多数仅通过 URLSession 使用标准 HTTPS 的应用可**豁免**——在 Info.plist 中设置 `ITSAppUsesNonExemptEncryption = NO` 以在每次上传时跳过问卷。技术参考位于 `https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations`。

---

## 5. 导致应用被拒绝的因素 — 数据和模式

Apple 位于 `https://www.apple.com/legal/more-resources/docs/2024-App-Store-Transparency-Report.pdf` 的 **2024 年 App Store 透明度报告**（2025 年 5 月发布）提供了硬数据：**审核了 777 万次提交，拒绝了 193 万次**（约 25% 拒绝率，同比增长 9.5%）。按数量计算，最主要的拒绝类别是**性能（第 1，约 123 万次拒绝）**、法律（第 2）、设计（第 3，37.83 万次）、商业（第 4）和安全（第 5）。

对于订阅应用，最高风险的拒绝模式是：

- **准则 2.1（应用完整性）** — 审核期间崩溃、沙盒购买失败、链接失效、占位符内容。超过 40% 的未解决问题属于此类。
- **准则 3.1.2（订阅）** — 元数据与应用内显示之间的定价不匹配；缺失或不可读的披露文本；"暗黑模式"，如在月度等价金额后隐藏年度定价；虚假紧迫感声明；应用内缺失使用条款/隐私政策链接。
- **缺失"恢复购买"** — 准则 3.1.1 明确要求为可恢复的 IAP 提供恢复机制。付费墙或设置页面缺失恢复按钮会立即被拒绝。
- **隐私清单违规（ITMS-91053）** — 自 2024 年 5 月起，缺失 Required Reason API 声明会在人工审核开始之前导致自动上传拒绝。
- **准则 5.1（隐私）** — 缺失隐私政策、数据收集披露不正确、缺失账户删除选项。

Apple 的**官方常见问题页面**位于 `https://developer.apple.com/distribute/app-review/`，**Tech Talk"预防常见审核问题的技巧"**位于 `https://developer.apple.com/videos/play/tech-talks/10885/`。Apple Developer Forums 的 FAQ 帖子 `https://developer.apple.com/forums/thread/131256` 提供审核时间预期（50% 在 24 小时内审核，90% 在 48 小时内）。

---

## 6. 验证和提交的工具参考

**Xcode 归档和验证**文档位于 `https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases`。Xcode 15+ 在 Organizer 中引入了简化的一键"TestFlight & App Store"分发。自动验证检查包括 entitlements 验证、代码签名、描述文件匹配、图标要求、Info.plist 验证、隐私清单检查和架构兼容性。使用 Organizer > 右键点击归档 > "Generate Privacy Report" 生成聚合所有隐私声明的 PDF。

位于 `https://developer.apple.com/documentation/appstoreconnectapi` 的 **App Store Connect API**（当前版本 3.7）支持以编程方式管理 IAP 元数据、订阅组、定价、应用版本、TestFlight 和提交。API 概览位于 `https://developer.apple.com/app-store-connect/api/`。

**Transporter**（Mac App Store 应用）提供拖放式 IPA/PKG 上传，文档位于 `https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/`。命令行变体 **iTMSTransporter** 可在 macOS、Windows 和 Linux 上运行，用于 CI/CD 自动化。**altool** 上传命令（`xcrun altool --validate-app`、`xcrun altool --upload-app`）仍然可用且未被弃用，但 altool 的公证子命令已于 2023 年 11 月移除，由 **notarytool**（`xcrun notarytool submit`）取代。

---

## 7. 值得参考的社区资源和 WWDC 会议

### 最佳社区参考

| 资源 | URL | 重要原因 |
|----------|-----|----------------|
| RevenueCat：App Store 拒绝终极指南 | `https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections/` | 最全面的社区拒绝指南；专注订阅 |
| RevenueCat：应用订阅发布清单 | `https://www.revenuecat.com/docs/test-and-launch/launch-checklist` | 订阅应用的发布前清单 |
| RevenueCat：Schedule 2 第 3.8(b) 节分析 | `https://www.revenuecat.com/blog/engineering/schedule-2-section-3-8-b/` | 解读必需的订阅披露语言 |
| Adapty：App Store 拒绝原因 | `https://adapty.io/blog/app-store-rejection/` | 数据驱动的拒绝指南，含 2024 年数据 |
| Adapty：Apple 付费墙准则 | `https://adapty.io/blog/how-to-design-paywall-to-pass-review-for-app-store/` | 付费墙合规模式 |
| GitHub：lukylab/appstore-submission-checklist | `https://github.com/lukylab/appstore-submission-checklist` | 新应用和更新的开源清单 |
| GitHub：rossbeale/iOS-App-Store-Submission-Checklist | `https://github.com/rossbeale/iOS-App-Store-Submission-Checklist` | 社区策划的经验驱动清单 |

### 必看 WWDC 会议

| 会议 | URL | 年份 | 主题 |
|---------|-----|------|-------|
| StoreKit 和应用内购买的新功能 | `https://developer.apple.com/videos/play/wwdc2024/10061/` | 2024 | StoreKit 1 弃用、赢回优惠 |
| 实现 App Store 优惠 | `https://developer.apple.com/videos/play/wwdc2024/10110/` | 2024 | 赢回优惠 + 优惠码 |
| 探索 App Store Server API | `https://developer.apple.com/videos/play/wwdc2024/10062/` | 2024 | 服务端 IAP 生命周期 |
| 认识 SwiftUI 的 StoreKit | `https://developer.apple.com/videos/play/wwdc2023/10013/` | 2023 | ProductView、SubscriptionStoreView |
| 隐私清单入门 | `https://developer.apple.com/videos/play/wwdc2023/10060/` | 2023 | 隐私清单实现 |
| 探索 IAP 测试 | `https://developer.apple.com/videos/play/wwdc2023/10142/` | 2023 | 全部 3 个测试环境走查 |
| 认识 StoreKit 2 | `https://developer.apple.com/videos/play/wwdc2021/10114/` | 2021 | StoreKit 2 基础介绍 |

---

## 8. 2024 年已变更或 2025-2026 年即将变更的要求

你的技能必须标记这些有时效性的要求：

**已执行（2024 年）：**
- **隐私清单** — 自 2024 年 5 月 1 日起强制要求含 Required Reason API 声明的 `PrivacyInfo.xcprivacy`；第三方 SDK 清单自 2025 年 2 月 12 日起执行
- **StoreKit 1 已弃用** — 原始 StoreKit API 在 iOS 18 中弃用；`verifyReceipt` 端点已弃用；须迁移至 StoreKit 2 和 App Store Server API
- **赢回优惠** — 用于重新吸引流失订阅者的新优惠类型，可在 App Store Connect 中配置
- **AI 数据共享披露** — 准则 5.1.2(i) 要求与第三方 AI 服务共享个人数据时获得明确同意（执行：2025 年 11 月）
- **欧盟 DMA 合规** — iOS 17.4+ 上的替代应用市场和支付提供商（仅限欧盟）；文档位于 `https://developer.apple.com/support/dma-and-apps-in-the-eu/`

**2025-2026 年即将到来：**
- **扩展年龄分级** — 新增 13+、16+、18+ 层级，含 AI/聊天机器人专用问题；须在 2026 年 1 月 31 日前回应
- **iOS/iPadOS 26 SDK 要求** — 自 2026 年 4 月 28 日起，应用必须使用 iOS 26 SDK 构建
- **隐私清单扩展** — Apple 将把 Required Reason 要求扩展到整个应用二进制文件（时间表待定）
- **欧盟商业模式整合** — 核心技术费将于 2026 年 1 月前由 5% 技术商业佣金取代

## 结论

审计技能应结构化为两条平行轨道——以隐私清单文档、entitlements 参考、StoreKit 2 框架文档和 ATS 要求为锚的**代码/entitlements 审计**，以及由 App Store Connect Help、截图规格和 Review Guidelines 驱动的**提交元数据清单**。本研究中价值最高的洞察是：**隐私清单和订阅披露合规**是"Apple 要求"与"大多数开发者实现"之间差距最大的两个领域——因此是技能中最值得强调的高 ROI 部分。接入 2024 年透明度报告的拒绝统计数据，按实际拒绝频率排定审计检查优先级，并内置机制定期检查 Apple 的 Upcoming Requirements 页面以获取截止日期驱动的执行变更。
