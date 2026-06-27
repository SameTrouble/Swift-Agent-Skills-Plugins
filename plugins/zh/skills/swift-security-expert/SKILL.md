---
name: swift-security-expert
description: 在处理 iOS/macOS Keychain Services（SecItem 查询、kSecClass、OSStatus 错误）、生物识别认证（LAContext、Face ID、Touch ID）、CryptoKit（AES-GCM、ChaChaPoly、ECDSA、ECDH、HPKE、ML-KEM）、Secure Enclave、安全凭据存储（OAuth 令牌、API 密钥）、证书锁定（SecTrust、SPKI）、跨 App/扩展的 Keychain 共享、从 UserDefaults 或 plist 迁移密钥，或 Apple 平台上的 OWASP MASVS/MASTG 移动合规性时使用。
license: MIT
---

# Keychain 与安全专家技能

> **理念：** 不带偏见、聚焦于正确性。本技能提供事实、经过验证的模式和 Apple 文档记录的最佳实践——而非架构强制要求。它以 iOS 13+ 作为最低部署目标，现代推荐面向 iOS 17+，并提供面向 iOS 26（后量子）的前瞻性指导。每个代码模式都基于 Apple 文档、DTS 工程师帖子（Quinn "The Eskimo!"）、WWDC 会议和 OWASP MASTG——绝不凭记忆。
>
> **本技能是什么：** 一个用于审查、改进和实现 Apple 平台上的 keychain 操作、生物识别认证、CryptoKit 密码学、凭据生命周期管理、证书信任和合规性映射的参考。
>
> **本技能不是什么：** 不是网络指南、不是服务端安全参考、也不是 App Transport Security 手册。TLS 配置、服务器证书管理和服务端认证架构不在范围内，除非它们直接涉及客户端 keychain 或信任 API。

---

## 决策树

确定用户的意图，然后遵循匹配的分支。如果含糊不清，请询问。

```
                        ┌─────────────────────┐
                        │  任务是什么？         │
                        └─────────┬───────────┘
               ┌──────────────────┼──────────────────┐
               ▼                  ▼                  ▼
          ┌─────────┐      ┌───────────┐      ┌────────────┐
          │ 审查     │      │  改进      │      │ 实现        │
          │         │      │           │      │            │
          │ 审计    │      │ 迁移 /    │      │ 从零构建    │
          │ 现有    │      │ 现代化    │      │            │
          │ 代码    │      │ 现有代码  │      │            │
          └────┬────┘      └─────┬─────┘      └─────┬──────┘
               │                 │                   │
               ▼                 ▼                   ▼
        运行顶层          识别差距            识别哪些
        审查清单           （遗留存储？          领域适用，
        （§ 见下文）对     错误 API？           加载参考
        代码进行审查。     缺少认证？）          文件，遵循
        将每项标记为      加载迁移 +            ✅ 模式。
        ✅ / ❌ /         领域特定              以 add-or-update
        ⚠️ N/A。          参考文件。            实现，具备
        对每个 ❌，        遵循 ✅ 模式，         正确的错误
        引用参考文件       用领域清单            处理，并从
        和具体章节。       验证。                一开始就具备
                                               正确的访问控制。
```

---

### 分支 1 — 审查（审计现有代码）

**目标：** 系统性地评估现有 keychain/安全代码的正确性、安全性和合规性。

**流程：**

1. **对受审查代码运行顶层审查清单**（见下文）。为每项评分 ✅ / ❌ / ⚠️ N/A。
2. **对每个 ❌ 失败**，加载引用的参考文件并定位具体的反模式或正确模式。
3. **交叉检查反模式**——对照 `common-anti-patterns.md` 中的全部 10 个条目扫描代码。特别关注：用 `UserDefaults` 存储密钥（#1）、硬编码密钥（#2）、将 `LAContext.evaluatePolicy()` 作为唯一认证门（#3）、忽略 `OSStatus`（#4）。
4. **检查合规性**——如果项目要求 OWASP MASVS 或企业审计就绪，将发现映射到 `compliance-owasp-mapping.md` 的 M1、M3、M9、M10 类别。
5. **报告格式：** 对每项发现，说明：问题是什么 → 哪个参考文件涵盖 → ✅ 正确模式 → 严重程度（CRITICAL / HIGH / MEDIUM）。

**审查的关键参考文件：**

- 从：`common-anti-patterns.md` 开始（主干——涵盖 10 个最危险的模式）
- 然后根据代码做什么加载领域特定文件
- 以：`compliance-owasp-mapping.md` 结束（如果合规性相关）

---

### 分支 2 — 改进（迁移 / 现代化）

**目标：** 将现有代码从不安全存储、废弃 API 或遗留模式升级到当前最佳实践。

**流程：**

1. **识别迁移类型：**
   - 不安全存储 → Keychain：加载 `migration-legacy-stores.md` + `credential-storage-patterns.md`
   - 遗留 Security framework → CryptoKit：加载 `cryptokit-symmetric.md` 或 `cryptokit-public-key.md` + `migration-legacy-stores.md`
   - RSA → 椭圆曲线：加载 `cryptokit-public-key.md`（RSA 迁移章节）
   - GenericPassword → InternetPassword（AutoFill）：加载 `keychain-item-classes.md`（迁移章节）
   - 仅 LAContext → Keychain 绑定的生物识别：加载 `biometric-authentication.md`
   - 基于文件的 keychain → 数据保护 keychain（macOS）：加载 `keychain-fundamentals.md`（TN3137 章节）
   - 单个 App → 共享 keychain（扩展）：加载 `keychain-sharing.md`
   - 叶证书锁定 → SPKI/CA 锁定：加载 `certificate-trust.md`

2. **遵循相关参考文件中的迁移模式。** 每个迁移章节包括：迁移前验证、原子迁移步骤、遗留数据安全删除、迁移后验证。

3. **迁移完成后运行参考文件中的领域特定清单。**

4. **使用 `testing-security-code.md` 中的指导验证无回归。**

---

### 分支 3 — 实现（从零构建）

**目标：** 从一开始就正确构建新的 keychain/安全功能。

**流程：**

1. **识别任务涉及哪些领域。** 使用下方的领域选择指南。
2. **加载相关参考文件。** 遵循 ✅ 代码模式——对于核心安全逻辑绝不偏离。
3. **将核心指导原则**（见下文）应用于每个实现。
4. **在认为实现完成之前运行领域特定清单。**
5. **遵循 `testing-security-code.md` 添加测试**——基于协议的抽象用于单元测试，真机上的真实 keychain 用于集成测试。

**领域选择指南：**

| 如果任务涉及…                     | 加载这些参考文件                                                |
| -------------------------------------- | ------------------------------------------------------------- |
| 存储/读取密码或令牌                    | `keychain-fundamentals.md` + `credential-storage-patterns.md` |
| 选择使用哪个 `kSecClass`               | `keychain-item-classes.md`                                    |
| 设置条目何时可访问                     | `keychain-access-control.md`                                  |
| Face ID / Touch ID 门控                | `biometric-authentication.md` + `keychain-access-control.md`  |
| 硬件支持的密钥                         | `secure-enclave.md`                                           |
| 加密 / 哈希数据                         | `cryptokit-symmetric.md`                                      |
| 签名 / 密钥协商 / HPKE                 | `cryptokit-public-key.md`                                     |
| OAuth 令牌 / API 密钥 / 登出           | `credential-storage-patterns.md`                              |
| 在 App 和扩展之间共享                  | `keychain-sharing.md`                                         |
| TLS 锁定 / 客户端证书                  | `certificate-trust.md`                                        |
| 替换 UserDefaults / plist 密钥         | `migration-legacy-stores.md`                                  |
| 为安全代码编写测试                     | `testing-security-code.md`                                    |
| 企业审计 / OWASP 合规                  | `compliance-owasp-mapping.md`                                 |

---

## 核心指导原则

这七条规则是不可协商的。每个 keychain/安全实现都必须满足所有这些规则。

**1. 永不忽略 `OSStatus`。** 每个 `SecItem*` 调用都返回 `OSStatus`。使用穷尽的 `switch`，至少覆盖：`errSecSuccess`、`errSecDuplicateItem` (-25299)、`errSecItemNotFound` (-25300)、`errSecInteractionNotAllowed` (-25308)。静默丢弃返回值是大多数 keychain bug 的根本原因。→ `keychain-fundamentals.md`

**2. 永不将 `LAContext.evaluatePolicy()` 作为独立认证门。** 它返回一个 `Bool`，可通过 Frida 在运行时轻松打补丁。生物识别认证必须与 keychain 绑定：使用 `.biometryCurrentSet` 将密钥存储在 `SecAccessControl` 后面，然后让 keychain 在 `SecItemCopyMatching` 期间提示 Face ID/Touch ID。keychain 在 Secure Enclave 中处理认证——没有可打补丁的 `Bool`。→ `biometric-authentication.md`

**3. 永不将密钥存储在 `UserDefaults`、`Info.plist`、`.xcconfig` 或 `NSCoding` 归档中。** 这些会生成可从未加密备份中读取的明文制品。Keychain 是 Apple 认可的唯一凭据存储。→ `credential-storage-patterns.md`、`common-anti-patterns.md`

**4. 永不在 `@MainActor` 上调用 `SecItem*`。** 每个 keychain 调用都是到 `securityd` 的 IPC 往返，会阻塞调用线程。使用专用 `actor`（iOS 17+）或串行 `DispatchQueue`（iOS 13–16）进行所有 keychain 访问。→ `keychain-fundamentals.md`

**5. 始终显式设置 `kSecAttrAccessible`。** 系统默认值（`kSecAttrAccessibleWhenUnlocked`）会破坏所有后台操作，且可能不符合你的威胁模型。选择满足你访问模式的最严格类别。对于后台任务：`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`。对于最高敏感度：`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`。→ `keychain-access-control.md`

**6. 始终使用 add-or-update 模式。** `SecItemAdd` 后在 `errSecDuplicateItem` 时执行 `SecItemUpdate`。绝不要 delete-then-add（会产生竞争窗口并破坏持久引用）。绝不要在不处理重复情况时调用 `SecItemAdd`。→ `keychain-fundamentals.md`

**7. 始终在 macOS 上以数据保护 keychain 为目标。** 在 macOS 目标上为每个 `SecItem*` 调用设置 `kSecUseDataProtectionKeychain: true`。没有它，查询会静默路由到遗留的基于文件的 keychain，其行为不同、忽略不支持的属性，且无法使用生物识别保护或 Secure Enclave 密钥。Mac Catalyst 和 iOS-on-Mac 会自动执行此操作。→ `keychain-fundamentals.md`

---

## 快速参考表

### 可访问性常量 — 选择指南

| 常量                             | 何时可解密                   | 在备份中存活 | 在设备迁移中存活 | 后台安全 | 何时使用                                               |
| -------------------------------- | ---------------------------- | ------------ | ---------------- | -------- | ------------------------------------------------------ |
| `WhenPasscodeSetThisDeviceOnly`  | 已解锁 + 已设置密码          | ❌           | ❌               | ❌       | 最高安全密钥；移除密码时删除                            |
| `WhenUnlockedThisDeviceOnly`     | 已解锁                       | ❌           | ❌               | ❌       | 后台不需要的设备绑定密钥                                |
| `WhenUnlocked`                   | 已解锁                       | ✅           | ✅               | ❌       | 可同步密钥（系统默认——避免隐式使用）                    |
| `AfterFirstUnlockThisDeviceOnly` | 首次解锁后 → 重启            | ❌           | ❌               | ✅       | **后台任务、推送处理器、设备绑定**                      |
| `AfterFirstUnlock`               | 首次解锁后 → 重启            | ✅           | ✅               | ✅       | 必须在恢复中存活的后台任务                              |

**已废弃（永不使用）：** `kSecAttrAccessibleAlways`、`kSecAttrAccessibleAlwaysThisDeviceOnly`——iOS 12 废弃。

**经验法则：** 需要后台访问（推送处理器、后台刷新）？从 `AfterFirstUnlockThisDeviceOnly` 开始。仅前台？从 `WhenUnlockedThisDeviceOnly` 开始。对于高价值密钥收紧到 `WhenPasscodeSetThisDeviceOnly`。仅在需要 iCloud 同步或备份迁移时使用非 `ThisDeviceOnly` 变体。

### CryptoKit 算法选择

| 需求                            | 算法                                             | 最低 iOS | 备注                                                                       |
| ------------------------------- | ------------------------------------------------ | -------- | --------------------------------------------------------------------------- |
| 哈希数据                         | `SHA256` / `SHA384` / `SHA512`                   | 13       | `SHA3_256`/`SHA3_512` iOS 18+ 可用                                          |
| 认证数据 (MAC)                   | `HMAC<SHA256>`                                   | 13       | 始终用常量时间比较验证（内置）                                              |
| 加密数据（认证的）               | `AES.GCM`                                        | 13       | 256 位密钥、96 位 nonce、128 位标签。**永不重用 nonce 与相同密钥**            |
| 加密数据（移动优化）             | `ChaChaPoly`                                     | 13       | 在没有 AES-NI 的设备上更好（旧款 Apple Watch）                              |
| 签名数据                         | `P256.Signing` / `Curve25519.Signing`            | 13       | 互操作用 P256，性能用 Curve25519                                            |
| 密钥协商                         | `P256.KeyAgreement` / `Curve25519.KeyAgreement`  | 13       | 始终通过 `HKDF` 派生对称密钥——绝不使用原始共享密钥                          |
| 混合公钥加密                     | `HPKE`                                           | 17       | 替代手动 ECDH+HKDF+AES-GCM 链                                              |
| 硬件支持的签名                   | `SecureEnclave.P256.Signing`                     | 13       | 仅 P256；密钥永不离开硬件                                                   |
| 后量子密钥协商                   | `MLKEM768`                                       | 26       | 形式化验证（ML-KEM FIPS 203）                                               |
| 后量子签名                       | `MLDSA65`                                        | 26       | 形式化验证（ML-DSA FIPS 204）                                               |
| 密码 → 密钥派生                  | PBKDF2（通过 `CommonCrypto`）                    | 13       | ≥600,000 次迭代 SHA-256（OWASP 2024）                                       |
| 密钥 → 密钥派生                  | `HKDF<SHA256>`                                   | 13       | 提取-然后-扩展；始终使用 info 参数进行域分离                                |

### 反模式检测 — 快速扫描

审查代码时，搜索这些模式。任何匹配都是一项发现。
`❌` = 要在用户代码中检测的不安全模式签名。`✅` = 在引用文件中应用纠正模式。

| 搜索内容                                                              | 反模式                         | 严重程度 | 参考                        |
| --------------------------------------------------------------------- | ------------------------------ | -------- | --------------------------- |
| `UserDefaults.standard.set` + token/key/secret/password               | 明文凭据存储                   | CRITICAL | `common-anti-patterns.md` #1 |
| 源码中硬编码 base64/十六进制字符串（≥16 字符）                        | 硬编码加密密钥                 | CRITICAL | `common-anti-patterns.md` #2 |
| `evaluatePolicy` 附近没有 `SecItemCopyMatching`                       | 仅 LAContext 生物识别门        | CRITICAL | `common-anti-patterns.md` #3 |
| `SecItemAdd` 未检查返回值 / `OSStatus`                                | 忽略错误码                     | HIGH     | `common-anti-patterns.md` #4 |
| 添加字典中没有 `kSecAttrAccessible`                                   | 隐式可访问性类别               | HIGH     | `common-anti-patterns.md` #5 |
| 在循环中用相同密钥的 `AES.GCM.Nonce()`                                | 潜在 nonce 重用                | CRITICAL | `common-anti-patterns.md` #6 |
| `sharedSecret.withUnsafeBytes` 没有 HKDF                              | 原始共享密钥作为密钥           | HIGH     | `common-anti-patterns.md` #7 |
| `kSecAttrAccessibleAlways`                                            | 废弃的可访问性                 | HIGH     | `keychain-access-control.md` |
| `SecureEnclave.isAvailable` 没有 `#if !targetEnvironment(simulator)`  | 模拟器假阴性陷阱               | MEDIUM   | `secure-enclave.md`         |
| `kSecAttrSynchronizable: true` + `ThisDeviceOnly`                     | 矛盾的约束                     | MEDIUM   | `keychain-item-classes.md`  |
| `SecTrustEvaluate`（同步，已废弃）                                    | 遗留信任评估                   | MEDIUM   | `certificate-trust.md`      |
| `kSecClassGenericPassword` + `kSecAttrServer`                         | Web 凭据用错类别               | MEDIUM   | `keychain-item-classes.md`  |

---

## 顶层审查清单

将此清单用于跨所有 14 个领域的快速扫描。每项映射到一个或多个参考文件以进行深入调查。对于领域特定的深度检查，使用每个参考文件底部的总结清单。

- [ ] **1. 密钥在 Keychain 中，不在 UserDefaults/plist/源码中** —— `UserDefaults`、`Info.plist`、`.xcconfig`、硬编码字符串或 `NSCoding` 归档中没有凭据、令牌或加密密钥。直接违反 OWASP M9（不安全数据存储）。→ `common-anti-patterns.md` #1–2、`credential-storage-patterns.md`、`migration-legacy-stores.md`、`compliance-owasp-mapping.md`

- [ ] **2. 每个 `OSStatus` 都被检查** —— 所有 `SecItem*` 调用都用穷尽 `switch` 或等效方式处理返回码。没有忽略的返回值。`errSecInteractionNotAllowed` 以非破坏性方式处理（稍后重试，绝不删除）。→ `keychain-fundamentals.md`、`common-anti-patterns.md` #4

- [ ] **3. 生物识别认证与 Keychain 绑定** —— 如果使用生物识别，认证通过 `SecAccessControl` + keychain 访问强制执行，而非单独使用 `LAContext.evaluatePolicy()`。→ `biometric-authentication.md`、`common-anti-patterns.md` #3

- [ ] **4. 可访问性类别显式且正确** —— 每个 keychain 条目都有与访问模式（后台 vs 前台、设备绑定 vs 可同步）匹配的显式 `kSecAttrAccessible` 值。没有废弃的 `Always` 常量。→ `keychain-access-control.md`

- [ ] **5. `@MainActor` 上没有 `SecItem*` 调用** —— 所有 keychain 操作在专用 `actor` 或后台队列上运行。UI 代码、`viewDidLoad` 或 `application(_:didFinishLaunchingWithOptions:)` 中没有同步 keychain 访问。→ `keychain-fundamentals.md`

- [ ] **6. 每种条目类型使用正确的 `kSecClass`** —— Web 凭据使用 `InternetPassword`（而非 GenericPassword）以支持 AutoFill。加密密钥使用 `kSecClassKey` 并带有正确的 `kSecAttrKeyType`。App 密钥使用 `GenericPassword` 并带有 `kSecAttrService` + `kSecAttrAccount`。→ `keychain-item-classes.md`

- [ ] **7. CryptoKit 使用正确** —— Nonce 永不与相同密钥重用。ECDH 共享密钥始终通过 `HKDF` 派生后用作对称密钥。`SymmetricKey` 材料存储在 Keychain 中，而非内存或文件中。加密操作由基于协议的单元测试覆盖。→ `cryptokit-symmetric.md`、`cryptokit-public-key.md`、`testing-security-code.md`

- [ ] **8. 尊重 Secure Enclave 约束** —— SE 密钥仅 P256（经典），永不导入（始终在设备上生成），设备绑定（无备份/同步）。可用性检查防范模拟器和 keychain-access-groups 权限问题。→ `secure-enclave.md`

- [ ] **9. 共享和访问组配置正确** —— `kSecAttrAccessGroup` 使用完整的 `TEAMID.group.identifier` 格式。App 和扩展之间的权限匹配。没有意外的跨 App 数据暴露。→ `keychain-sharing.md`

- [ ] **10. 证书信任评估是最新的** —— 使用 `SecTrustEvaluateAsyncWithError`（而非废弃的同步 `SecTrustEvaluate`）。锁定策略使用 SPKI 哈希或 `NSPinnedDomains`（而非叶证书锁定，后者在年度轮换时失效）。→ `certificate-trust.md`

- [ ] **11. macOS 目标使用数据保护 keychain** —— 所有 macOS `SecItem*` 调用包含 `kSecUseDataProtectionKeychain: true`（Mac Catalyst / iOS-on-Mac 除外，那里是自动的）。→ `keychain-fundamentals.md`

---

## 参考文件索引

| #   | 文件                            | 一句话描述                                                                                                            | 风险      |
| --- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------- | --------- |
| 1   | `keychain-fundamentals.md`      | SecItem\* CRUD、查询字典、OSStatus 处理、基于 actor 的包装器、macOS TN3137 路由                                       | CRITICAL  |
| 2   | `keychain-item-classes.md`      | 五种 kSecClass 类型、复合主键、GenericPassword vs InternetPassword、ApplicationTag vs ApplicationLabel                | HIGH      |
| 3   | `keychain-access-control.md`    | 七个可访问性常量、SecAccessControl 标志、数据保护层级、NSFileProtection 侧栏                                         | CRITICAL  |
| 4   | `biometric-authentication.md`   | Keychain 绑定的生物识别、LAContext 绕过漏洞、注册变更检测、回退链                                                     | CRITICAL  |
| 5   | `secure-enclave.md`             | 硬件支持的 P256 密钥、CryptoKit SecureEnclave 模块、持久化、模拟器陷阱、iOS 26 后量子                                 | HIGH      |
| 6   | `cryptokit-symmetric.md`        | SHA-2/3 哈希、HMAC、AES-GCM/ChaChaPoly 加密、SymmetricKey 管理、nonce 处理、HKDF/PBKDF2                               | HIGH      |
| 7   | `cryptokit-public-key.md`       | ECDSA 签名、ECDH 密钥协商、HPKE (iOS 17+)、ML-KEM/ML-DSA 后量子 (iOS 26+)、曲线选择                                   | HIGH      |
| 8   | `credential-storage-patterns.md`| OAuth2/OIDC 令牌生命周期、API 密钥存储、刷新令牌轮换、运行时密钥、登出清理                                            | CRITICAL  |
| 9   | `keychain-sharing.md`           | 访问组、Team ID 前缀、App 扩展、Keychain Sharing vs App Groups 权限、iCloud 同步                                     | MEDIUM    |
| 10  | `certificate-trust.md`          | SecTrust 评估、SPKI/CA/叶锁定、NSPinnedDomains、客户端证书 (mTLS)、信任策略                                          | HIGH      |
| 11  | `migration-legacy-stores.md`    | UserDefaults/plist/NSCoding → Keychain 迁移、安全删除、首次启动清理、版本化迁移                                      | MEDIUM    |
| 12  | `common-anti-patterns.md`       | 前 10 个 AI 生成的安全错误及 ❌/✅ 代码对、检测启发式、OWASP 映射                                                     | CRITICAL  |
| 13  | `testing-security-code.md`      | 基于协议的 mock、模拟器 vs 设备差异、CI/CD keychain、Swift Testing、变异测试                                         | MEDIUM    |
| 14  | `compliance-owasp-mapping.md`   | OWASP Mobile Top 10 (2024)、MASVS v2.1.0、MASTG 测试 ID、M1/M3/M9/M10 映射、审计就绪                                 | MEDIUM    |

---

## 权威来源

这些是支撑所有参考文件的主要来源。有疑问时，以这些为准，而非任何次要来源。

- **Apple Keychain Services 文档** —— 标准 API 参考
- **Apple Platform Security Guide**（年度更新）—— 架构和加密设计
- **TN3137: "On Mac Keychain APIs and Implementations"** —— macOS 数据保护 vs 基于文件的 keychain
- **Quinn "The Eskimo!" DTS 帖子** —— "SecItem: Fundamentals" 和 "SecItem: Pitfalls and Best Practices"（更新至 2025 年）
- **WWDC 2019 Session 709** —— "Cryptography and Your Apps"（CryptoKit 介绍）
- **WWDC 2025 Session 314** —— "Get ahead with quantum-secure cryptography"（ML-KEM、ML-DSA）
- **OWASP Mobile Top 10 (2024)** + **MASVS v2.1.0** + **MASTG v2** —— 合规框架
- **CISA/FBI "Product Security Bad Practices" v2.0**（2025 年 1 月）—— 硬编码凭据被归类为国家安全风险

---

## 代理行为规则

> 以下章节规定 AI 代理在使用本技能时应如何行为：什么在范围内、什么不在、语气校准、要避免的常见错误、如何选择参考文件，以及输出格式要求。

### 范围边界 — 包含内容

本技能在 iOS、macOS、tvOS、watchOS 和 visionOS 上的**客户端 Apple 平台安全**方面具有权威性：

- **Keychain Services** —— `SecItemAdd`、`SecItemCopyMatching`、`SecItemUpdate`、`SecItemDelete`、查询字典构造、`OSStatus` 处理、actor/线程隔离、macOS 上的数据保护 keychain (TN3137)
- **Keychain 条目类别** —— `kSecClassGenericPassword`、`kSecClassInternetPassword`、`kSecClassKey`、`kSecClassCertificate`、`kSecClassIdentity`、复合主键、AutoFill 集成
- **访问控制** —— 七个 `kSecAttrAccessible` 常量、`SecAccessControlCreateWithFlags`、数据保护层级、`NSFileProtection` 对应关系
- **生物识别认证** —— `LAContext` + keychain 绑定、布尔门漏洞、注册变更检测、回退链、`evaluatedPolicyDomainState`
- **Secure Enclave** —— CryptoKit `SecureEnclave.P256` 模块、硬件约束（仅 P256、不导入、不导出、不对称）、通过 keychain 持久化、模拟器陷阱、iOS 26 后量子（ML-KEM、ML-DSA）
- **CryptoKit 对称** —— SHA-2/SHA-3 哈希、HMAC、AES-GCM、ChaChaPoly、`SymmetricKey` 生命周期、nonce 处理、HKDF、PBKDF2
- **CryptoKit 公钥** —— ECDSA 签名（P256/Curve25519）、ECDH 密钥协商、HPKE (iOS 17+)、ML-KEM/ML-DSA (iOS 26+)、曲线选择
- **凭据存储模式** —— OAuth2/OIDC 令牌生命周期、API 密钥存储、刷新令牌轮换、运行时密钥获取、登出清理
- **Keychain 共享** —— 访问组、Team ID 前缀、`keychain-access-groups` vs `com.apple.security.application-groups` 权限、扩展、iCloud Keychain 同步
- **证书信任** —— `SecTrust` 评估、SPKI/CA/叶锁定、`NSPinnedDomains`、客户端证书 (mTLS)、信任策略
- **迁移** —— UserDefaults/plist/NSCoding → Keychain 迁移、安全遗留删除、首次启动清理、版本化迁移
- **测试** —— 基于协议的 mock、模拟器 vs 设备差异、CI/CD keychain 创建、Swift Testing 模式
- **合规性** —— OWASP Mobile Top 10 (2024)、MASVS v2.1.0、MASTG v2 测试 ID、CISA/FBI Bad Practices

**在范围内的边缘情况：** 用于 mTLS 锁定的客户端证书加载（`certificate-trust.md`）。Keychain 中的 Passkey/AutoFill 凭据存储（`keychain-item-classes.md`、`credential-storage-patterns.md`）。`@AppStorage` 被标记为不安全存储——重定向到 Keychain（`common-anti-patterns.md`）。

### 范围边界 — 排除内容

**不要**使用本技能回答以下主题。简要说明它们不在范围内并建议去哪里查找。

| 主题                                            | 排除原因                                                         | 重定向到                                                                                                                                          |
| ----------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **App Transport Security (ATS)**                | 服务端 TLS 策略，而非客户端 keychain                              | Apple 的 ATS 文档、`Info.plist` NSAppTransportSecurity 参考                                                                                        |
| **CloudKit 加密**                               | 服务端管理的密钥层次，而非客户端 CryptoKit                        | CloudKit 文档、`CKRecord.encryptedValues`                                                                                                         |
| **网络安全 / URLSession TLS 配置**              | 传输层，而非存储层                                                | Apple URL Loading System 文档；本技能仅涵盖用于 mTLS 的客户端证书加载                                                                             |
| **服务端认证架构**                              | 后端 JWT 签发、OAuth 提供者配置                                   | OWASP ASVS（Application Security Verification Standard）                                                                                          |
| **WebAuthn / passkeys 服务端**                  | 依赖方实现                                                        | Apple "Supporting passkeys" 文档；本技能仅在凭据存储于 Keychain 时涵盖客户端 `ASAuthorizationController`                                            |
| **代码签名 / 配置文件**                         | 构建/分发，而非运行时安全                                         | Apple 代码签名文档                                                                                                                                |
| **越狱检测**                                    | 运行时完整性，而非加密存储                                        | OWASP MASTG MSTG-RESILIENCE 类别                                                                                                                  |
| **SwiftUI `@AppStorage`**                       | `UserDefaults` 的包装器——除标记为不安全外不在范围内               | `common-anti-patterns.md` #1 标记它；无更深入覆盖                                                                                                 |
| **跨平台加密 (OpenSSL、LibSodium)**             | 第三方库，而非 Apple 框架                                         | 各自的库文档                                                                                                                                      |

---

### 语气规则

本技能**不带偏见且聚焦于正确性**。语气根据严重程度校准。

**默认语气——建议性。** 使用"考虑"、"建议"、"一种方法是"、"一种常见模式是"用于：架构选择（包装类设计、actor vs DispatchQueue）、存在多个有效选项时的算法选择（P256 vs Curve25519、AES-GCM vs ChaChaPoly）、威胁模型不明确时的可访问性类别选择、测试策略、代码组织。

**提升语气——指令性。** 仅对上述七个核心指导原则和 `common-anti-patterns.md` 中的 10 个反模式使用"始终"、"永不"、"必须"。这些是安全不变量，不是风格偏好。指令的完整列表：

1. 永不忽略 `OSStatus`——始终检查 `SecItem*` 调用的返回码。→ `keychain-fundamentals.md`
2. 永不将 `LAContext.evaluatePolicy()` 作为独立认证门——始终将生物识别绑定到 keychain 条目。→ `biometric-authentication.md`
3. 永不将密钥存储在 `UserDefaults`、`Info.plist`、`.xcconfig` 或 `NSCoding` 归档中。→ `credential-storage-patterns.md`、`common-anti-patterns.md`
4. 永不在 `@MainActor` 上调用 `SecItem*`——始终使用后台 actor 或队列。→ `keychain-fundamentals.md`
5. 始终在每个 `SecItemAdd` 上显式设置 `kSecAttrAccessible`。→ `keychain-access-control.md`
6. 始终使用 add-or-update 模式（`SecItemAdd` → 在 `errSecDuplicateItem` 时 `SecItemUpdate`）。→ `keychain-fundamentals.md`
7. 始终在 macOS 目标上设置 `kSecUseDataProtectionKeychain: true`。→ `keychain-fundamentals.md`
8. 永不重用 nonce 与相同的 AES-GCM 密钥。→ `cryptokit-symmetric.md`、`common-anti-patterns.md`
9. 永不将原始 ECDH 共享密钥用作对称密钥——始终通过 HKDF 派生。→ `cryptokit-public-key.md`、`common-anti-patterns.md`
10. 永不将 `Insecure.MD5` 或 `Insecure.SHA1` 用于安全目的。→ `cryptokit-symmetric.md`、`common-anti-patterns.md`

如果某个模式不在此列表中，使用建议性语气。不要将警告升级到超出参考文件支持的程度。

**拒绝时的语气。** 当查询超出范围时，直接但不轻视："本技能涵盖客户端 keychain 和 CryptoKit。对于 ATS 配置，Apple 的 NSAppTransportSecurity 文档是正确的参考。"说明边界、建议替代方案、继续。

---

### 常见 AI 错误 — 10 个最可能的不正确输出

在最终确定任何输出前，扫描所有 10 个。每个都链接到包含正确模式的参考文件。
每个条目都是有意图配对的：`❌` 不正确的生成行为和 `✅` 要使用的纠正模式。

**错误 #1 — 生成 `LAContext.evaluatePolicy()` 作为唯一生物识别门。** AI 产生布尔回调模式，其中 `evaluatePolicy` 返回 `success: Bool`，App 基于该布尔门控访问。该布尔存在于可 hook 的用户空间内存中——Frida/objection 用一条命令绕过。**✅ 正确模式：** 使用 `.biometryCurrentSet` 将密钥存储在 `SecAccessControl` 后面，通过 `SecItemCopyMatching` 检索。→ `biometric-authentication.md`

**错误 #2 — 建议不带模拟器保护的 `SecureEnclave.isAvailable`。** AI 生成不带 `#if !targetEnvironment(simulator)` 的 `if SecureEnclave.isAvailable { ... }`。在模拟器上，`isAvailable` 返回 `false`，在所有模拟器测试中静默走回退路径。**✅ 正确模式：** 使用 `#if targetEnvironment(simulator)` 在编译时抛出/返回明确错误，仅在设备构建中检查 `SecureEnclave.isAvailable`。→ `secure-enclave.md`

**错误 #3 — 将外部密钥导入 Secure Enclave。** AI 生成 `SecureEnclave.P256.Signing.PrivateKey(rawRepresentation: someData)`。SE 密钥必须在硬件内部生成——SE 类型上没有 `init(rawRepresentation:)`。`init(dataRepresentation:)` 仅接受来自先前创建的 SE 密钥的不透明加密 blob。**✅ 正确模式：** 在 SE 内部生成，将不透明的 `dataRepresentation` 持久化到 keychain，通过 `init(dataRepresentation:)` 恢复。→ `secure-enclave.md`

**错误 #4 — 使用 `SecureEnclave.AES` 或 SE 进行对称加密。** AI 生成对不存在的 SE 对称 API 的引用。SE 的内部 AES 引擎不作为开发者 API 暴露。iOS 26 之前，SE 仅支持 P256 签名和密钥协商。iOS 26 添加了 ML-KEM 和 ML-DSA，而非对称原语。**✅ 正确模式：** 使用 SE 进行签名/密钥协商；通过 ECDH + HKDF 派生 `SymmetricKey` 用于加密。→ `secure-enclave.md`、`cryptokit-symmetric.md`

**错误 #5 — 在 `SecItemAdd` 中省略 `kSecAttrAccessible`。** AI 构建不带可访问性属性的添加字典。系统默认应用 `kSecAttrAccessibleWhenUnlocked`，这会破坏后台操作并使安全策略在代码审查中不可见。**✅ 正确模式：** 始终显式设置 `kSecAttrAccessible`。→ `keychain-access-control.md`

**错误 #6 — 使用 `SecItemAdd` 不处理 `errSecDuplicateItem`。** AI 仅检查 `errSecSuccess`，或使用 delete-then-add。不处理重复，第二次保存会静默失败。Delete-then-add 会产生竞争窗口并破坏持久引用。**✅ 正确模式：** Add-or-update 模式。→ `keychain-fundamentals.md`

**错误 #7 — 为 AES-GCM 加密指定显式 nonce。** AI 手动创建 nonce 并传递给 `AES.GCM.seal`。手动 nonce 管理会招致重用——单次重用会揭示两个明文的 XOR。CryptoKit 在省略参数时自动生成加密随机 nonce。**✅ 正确模式：** 调用 `AES.GCM.seal(plaintext, using: key)` 不带 `nonce:` 参数。→ `cryptokit-symmetric.md`、`common-anti-patterns.md` #6

**错误 #8 — 使用原始 ECDH 共享密钥作为对称密钥。** AI 取 `sharedSecretFromKeyAgreement` 的输出并通过 `withUnsafeBytes` 直接使用。原始共享密钥分布不均匀。CryptoKit 的 `SharedSecret` 特意没有 `withUnsafeBytes`——此代码需要不安全的变通方法，这是滥用的明确信号。**✅ 正确模式：** 始终通过 `sharedSecret.hkdfDerivedSymmetricKey(...)` 派生。→ `cryptokit-public-key.md`、`common-anti-patterns.md` #7

**错误 #9 — 声称 SHA-3 需要 iOS 26。** AI 将 2025 年 WWDC 的后量子添加与 2024 年的 SHA-3 添加混淆。SHA-3 系列类型在 **iOS 18 / macOS 15** 中添加。iOS 26 引入了 ML-KEM 和 ML-DSA，而非 SHA-3。**✅ 正确版本标签：** SHA-3 → iOS 18+。ML-KEM/ML-DSA → iOS 26+。→ `cryptokit-symmetric.md`

**错误 #10 — 缺少首次启动 keychain 清理。** AI 生成不带 keychain 清理的标准 `@main struct MyApp: App`。Keychain 条目在 App 卸载后仍然存在。重新安装的 App 会继承陈旧令牌、过期密钥和孤立凭据。**✅ 正确模式：** 检查 `UserDefaults` 标志，首次启动时对所有五种 `kSecClass` 类型执行 `SecItemDelete`。→ `common-anti-patterns.md` #9、`migration-legacy-stores.md`

---

### 参考文件加载规则

加载回答查询所需的**最小集合**。不要加载全部 14 个——它们总计约 7,000+ 行，会稀释焦点。

| 查询类型                          | 加载这些文件                                                                      | 原因                                |
| --------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------- |
| "审查我的 keychain 代码"          | `common-anti-patterns.md` → 然后根据代码做什么加载领域特定文件                    | 反模式文件是审查主干                |
| "这个生物识别认证安全吗？"        | `biometric-authentication.md` + `common-anti-patterns.md` (#3)                    | 布尔门是 #1 生物识别风险            |
| "存储令牌 / 密码"                 | `keychain-fundamentals.md` + `credential-storage-patterns.md`                     | CRUD + 生命周期                      |
| "加密 / 哈希数据"                 | `cryptokit-symmetric.md`                                                          | 对称操作                            |
| "签名数据 / 密钥协商"             | `cryptokit-public-key.md`                                                         | 非对称操作                          |
| "使用 Secure Enclave"             | `secure-enclave.md` + `keychain-fundamentals.md`                                  | SE 密钥需要 keychain 持久化         |
| "与扩展共享 keychain"             | `keychain-sharing.md` + `keychain-fundamentals.md`                                | 访问组 + CRUD                        |
| "从 UserDefaults 迁移"            | `migration-legacy-stores.md` + `credential-storage-patterns.md`                   | 迁移 + 目标模式                      |
| "TLS 锁定 / mTLS"                 | `certificate-trust.md`                                                            | 信任评估                            |
| "哪个 kSecClass？"                | `keychain-item-classes.md`                                                        | 类别选择 + 主键                     |
| "设置数据保护"                    | `keychain-access-control.md`                                                      | 可访问性常量                        |
| "为 keychain 代码编写测试"        | `testing-security-code.md`                                                        | 协议 mock + CI/CD                   |
| "OWASP 合规审计"                  | `compliance-owasp-mapping.md` + `common-anti-patterns.md`                         | 映射 + 检测                         |
| "全面安全审查"                    | `common-anti-patterns.md` + 代码涉及的所有文件                                    | 从反模式开始，扩展                  |

**加载顺序：** (1) 查询最特定的文件。(2) 为任何审查/审计添加 `common-anti-patterns.md`。(3) 为任何 `SecItem*` 任务添加 `keychain-fundamentals.md`。(4) 仅在提及 OWASP/审计时添加 `compliance-owasp-mapping.md`。(5) 永不推测性地加载文件。

---

### 输出格式规则

**1. 始终包含 ✅/❌ 代码示例。** 同时展示不正确/不安全版本和正确/安全版本。例外：纯信息查询（"存在哪些可访问性常量？"）不需要 ❌ 示例。

**2. 始终引用 iOS 版本要求。** 每个 API 推荐必须内联包含最低 iOS 版本："使用 `HPKE` (iOS 17+) 进行混合公钥加密。"

**3. 始终引用参考文件。** 引用模式或反模式时，指明来源："见 `biometric-authentication.md` 了解完整的 keychain 绑定模式。"

**4. 始终在 keychain 代码中包含 `OSStatus` 处理。** 永不输出没有错误处理的裸 `SecItemAdd` / `SecItemCopyMatching` 调用。至少：`errSecSuccess`、`errSecDuplicateItem`（添加）、`errSecItemNotFound`（读取）、`errSecInteractionNotAllowed`（非破坏性重试）。

**5. 始终在添加示例中指定 `kSecAttrAccessible`。** 每个 `SecItemAdd` 代码示例必须包含显式可访问性常量。

**6. 为发现说明严重程度。** CRITICAL = 可利用的漏洞。HIGH = 静默数据丢失或错误的安全边界。MEDIUM = 次优但不可立即利用。

**7. 优先使用现代 API 并附回退说明。** 默认 iOS 17+（基于 actor）。注意回退：iOS 15–16（串行 DispatchQueue + async/await 桥接）、iOS 13–14（完成处理器）。

**8. 永不编造引用或 WWDC 会议编号。** 如果会议/引用不在已加载的参考中，说明它未经验证并避免编造标识符。

**9. 实现和改进响应必须以 `## 参考文件` 章节结束。** 列出为响应提供信息的每个参考文件及一行说明其贡献。这适用于所有响应类型——代码生成、迁移指南和改进——不仅仅是审查。示例：`- \`keychain-fundamentals.md\` — SecItem CRUD 和错误处理`。

**10. 当 SKILL.md 结构章节主导响应时引用它们。** 拒绝超出范围的查询时，引用"范围边界 — 排除内容"。在观点寻求问题上使用建议性 vs 指令性语气时，引用"语气规则"。当版本约束影响答案时，引用"版本基线快速参考"。简短的括号说明即可——例如"（根据范围边界 — 排除内容）"。

---

### 行为边界

**代理必须做的事：**

- 将每个代码模式建立在参考文件中。如果某个模式未文档化，说明并建议对照 Apple 文档验证。
- 当代码仅在模拟器测试时标记。模拟器行为在 Secure Enclave、keychain 和生物识别方面有所不同。
- 区分编译时 vs 运行时错误。SE 密钥导入 = 编译时。缺少可访问性类别 = 运行时（静默错误默认）。缺少 OSStatus 检查 = 运行时（丢失错误）。

**代理不得做的事：**

- 不要编造 WWDC 会议编号。仅引用参考文件中文档化的会议。
- ✅ 示例必须始终使用原生 API——绝不第三方库代码（KeychainAccess、SAMKeychain、Valet）。当用户明确要求比较原生 API 与第三方库时，采用建议性语气：客观呈现权衡而不指令性拒绝。模式：_"原生 API 没有依赖开销；KeychainAccess 和 Valet 减少样板代码但代价是耦合到第三方维护计划。"_ 不要说"本技能不建议..."——那是核心指导原则之外的指令性输出。
- 不要在没有证据的情况下声称 Apple API 有 bug。在建议 API 缺陷前指导调试（查询字典错误、缺少权限、错误的 keychain）。
- 当 CryptoKit 覆盖用例（iOS 13+）时，不要生成 Security framework 代码。
- 不要输出部分 keychain 操作。绝不展示没有 `errSecDuplicateItem` 回退的 `SecItemAdd`。绝不展示没有 `errSecItemNotFound` 处理的 `SecItemCopyMatching`。
- 不要将语气升级到超出参考文件支持的程度。

---

### 交叉引用协议

- **规范来源：** 每个模式有一个主要参考文件（根据上面的参考索引）。
- **简要提及 + 重定向到其他地方：** 其他文件获得一句话总结，而非完整代码示例。
- **代理行为：** 引用规范文件。加载它获取细节。不要从次要提及重构模式。

---

### 版本基线快速参考

| API / 功能                                     | 最低 iOS                        | 常见 AI 错误                |
| --------------------------------------------- | ------------------------------- | --------------------------- |
| CryptoKit (SHA-2、AES-GCM、P256、ECDH)        | 13                              | 声称 iOS 15+                |
| `SecureEnclave.P256` (CryptoKit)              | 13                              | 声称 iOS 15+                |
| SHA-3 (`SHA3_256`、`SHA3_384`、`SHA3_512`)    | **18**                          | 声称 iOS 26+                |
| HPKE (`HPKE.Sender`、`HPKE.Recipient`)        | **17**                          | 声称 iOS 15+ 或 iOS 18+     |
| ML-KEM / ML-DSA（后量子）                      | **26**                          | 与 SHA-3 混淆               |
| `SecAccessControl` 与 `.biometryCurrentSet`   | 11.3                            | 声称 iOS 13+                |
| `kSecUseDataProtectionKeychain` (macOS)       | macOS 10.15                     | 在 macOS 上完全省略         |
| Swift 并发 `actor`                            | 13（运行时）、17+（推荐）       | 声称 iOS 15 最低            |
| `LAContext.evaluatedPolicyDomainState`        | 9                               | 不知道它存在                |
| `NSPinnedDomains`（声明式锁定）               | 14                              | 声称 iOS 16+                |

---

### 代理自审清单

在最终确定任何包含安全代码的响应前运行：

- [ ] 每个 `SecItemAdd` 都有显式 `kSecAttrAccessible` 值
- [ ] 每个 `SecItemAdd` 都用 `SecItemUpdate` 回退处理 `errSecDuplicateItem`
- [ ] 每个 `SecItemCopyMatching` 都处理 `errSecItemNotFound`
- [ ] 没有将 `LAContext.evaluatePolicy()` 用作独立认证门
- [ ] `@MainActor` 或主线程上没有 `SecItem*` 调用
- [ ] macOS 代码包含 `kSecUseDataProtectionKeychain: true`
- [ ] Secure Enclave 代码有 `#if targetEnvironment(simulator)` 保护
- [ ] 没有原始 ECDH 共享密钥用作对称密钥
- [ ] `AES.GCM.seal` 中没有显式 nonce，除非用户有文档化原因
- [ ] 每个 API 推荐都有 iOS 版本标签
- [ ] 展示的每个模式都引用了参考文件
- [ ] 每项发现都说明严重程度（审查/审计任务）
- [ ] 没有编造的 WWDC 会议编号
