# Keychain 访问控制

> 范围：选择 `kSecAttrAccessible` 类别和 `SecAccessControl` 标志，为 keychain 条目强制执行正确的锁定状态和用户存在保证。

数据保护类别（`kSecAttrAccessible`）和运行时认证门（`SecAccessControl`）构成保护每个 keychain 条目的双层安全模型。第一层控制基于设备状态何时条目的类别密钥在内存中可用；第二层控制访问时用户必须如何认证。两者都必须满足才能成功读取。搞错这是生产 keychain 失败的最常见原因——后台操作静默返回 `nil`、设备迁移后条目消失或凭据在静态时可解密。

来源：Apple Platform Security Guide（2024–2026 版）、Apple Keychain Services 文档、TN3137、WWDC 2014 Session 711（"Keychain and Authentication with Touch ID"）、WWDC 2015 Session 706、SecAccessControl 文档、OWASP MASTG。

---

## "何时"层：七个可访问性常量

每个 keychain 条目都由从设备硬件 UID 和（对于大多数类别）用户密码派生的类别密钥加密。`kSecAttrAccessible` 属性选择哪个类别密钥保护条目，决定系统何时可以解密它。**如果省略 `kSecAttrAccessible`，默认是 `kSecAttrAccessibleWhenUnlocked`**——由 Apple 文档确认。此默认破坏所有后台操作。

### 保护频谱

从最严格到最不严格列出：

**`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`** (iOS 8+) —— 最高安全类别。条目仅在解锁时可访问，且仅当设备密码当前已设置时。两个独特行为：(1) `SecItemAdd` 在无密码设备上失败，(2) **移除密码永久删除此类别中的所有条目**——类别密钥被丢弃，数据不可恢复。不存在非 `ThisDeviceOnly` 变体。条目不同步到 iCloud Keychain，不备份，不在托管 keybag 中。

**`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`** —— 条目仅解锁时可解密。设备绑定：排除在备份和设备迁移外。

**`kSecAttrAccessibleWhenUnlocked`** ⭐（系统默认）—— 与上面相同的锁定状态行为，但条目随加密备份迁移。映射到 `NSFileProtectionComplete`。类别密钥在设备锁定后短时间内从内存丢弃（设置为立即要求密码时约 10 秒）。

**`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`** —— **后台操作的正确选择。** 用户重启后首次解锁设备后，类别密钥保留在内存中直到下次重启——即使锁定。设备绑定。

**`kSecAttrAccessibleAfterFirstUnlock`** —— 相同的后台可访问性，但条目随加密备份迁移。Apple 将此用于系统 Wi-Fi 密码、邮件账户和 iCloud 令牌。映射到 `NSFileProtectionCompleteUntilFirstUserAuthentication`。

**`kSecAttrAccessibleAlwaysThisDeviceOnly`** ⚠️ 废弃 —— iOS 12 / macOS 10.14 中废弃。Apple 在 WWDC 2015 Session 706 宣布意图。

**`kSecAttrAccessibleAlways`** ⚠️ 废弃 —— 相同的废弃。条目仅由设备 UID 加密（无密码参与），等效于 `NSFileProtectionNone`。

> **交叉验证说明——废弃的"Always"运行时行为：** 一个研究来源报告这些常量"在运行时仍按原始语义工作"在 iOS 15–18 上。另一个报告现代 iOS 静默将它们重映射为 `AfterFirstUnlock` 行为。无论哪种方式，实际指导相同：**立即迁移到 `kSecAttrAccessibleAfterFirstUnlock`**。在 CI linting 中阻止这些常量。不要依赖跨 OS 版本的废弃常量的任何特定运行时行为。

### 快速参考表

| 常量                         | 何时可访问           | 锁定后存活 | 备份中迁移 | 特殊                         |
| ---------------------------- | -------------------- | ---------- | ---------- | ---------------------------- |
| `WhenPasscodeSetThisDeviceOnly`  | 解锁 + 已设置密码    | 否         | 否         | **移除密码时删除**           |
| `WhenUnlockedThisDeviceOnly`     | 解锁                | 否         | 否         | —                            |
| `WhenUnlocked` ⭐ 默认        | 解锁                | 否         | 是         | —                            |
| `AfterFirstUnlockThisDeviceOnly` | 首次解锁后          | 是         | 否         | 后台安全                     |
| `AfterFirstUnlock`               | 首次解锁后          | 是         | 是         | 后台安全 + 可迁移            |
| `AlwaysThisDeviceOnly` ⚠️        | 始终¹               | 是         | 否         | iOS 12 废弃                  |
| `Always` ⚠️                      | 始终¹               | 是         | 是         | iOS 12 废弃                  |

¹ 在现代 iOS 版本上行为可能被重映射为 `AfterFirstUnlock`。

### 锁定状态频谱解释

设备重启后，系统处于**首次解锁前 (BFU)** 状态。只有带废弃 `Always` 类别的条目应该可访问。即使是 `AfterFirstUnlock` 条目也被锁定。

用户输入密码后，设备进入**首次解锁后 (AFU)** 状态。`AfterFirstUnlock` 类别密钥加载到内存并保留到下次重启。`WhenUnlocked` 类别密钥仅在主动解锁期间可用，每次设备锁定时丢弃。

> **iOS 15+ 注意——App 预热：** iOS 可能在首次解锁前启动你的进程以加速 App 启动。这意味着即使是 `AfterFirstUnlock` 条目在预热期间也可能暂时不可用。访问 keychain 条目前检查 `UIApplication.shared.isProtectedDataAvailable`，如果返回 `false` 则推迟。

---

## "如何"层：SecAccessControl 标志

`SecAccessControl` 在静态数据保护之上添加运行时认证要求。它通过 `SecAccessControlCreateWithFlags` 创建，将可访问性级别嵌入控制对象：

```swift
func SecAccessControlCreateWithFlags(
    _ allocator: CFAllocator?,       // 传 nil
    _ protection: CFTypeRef,          // 一个 kSecAttrAccessible 常量
    _ flags: SecAccessControlCreateFlags,
    _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> SecAccessControl?
```

### 可用标志

**认证约束：**

- **`.userPresence`** (iOS 8+) —— 生物识别或密码。不要求生物识别注册；自动回退到密码。等效于 `[.biometryAny, .or, .devicePasscode]` 但优雅处理无生物识别。
- **`.biometryAny`** (iOS 11.3+，原 `.touchIDAny`) —— 要求生物识别认证。条目**在注册变更后存活**（新指纹、Face ID 重新注册）。
- **`.biometryCurrentSet`** (iOS 11.3+，原 `.touchIDCurrentSet`) —— 要求生物识别认证。条目**在注册变更时失效**。最安全的生物识别选项——阻止注册自己生物识别的攻击者。
- **`.devicePasscode`** (iOS 9+) —— 仅要求设备密码输入。

**逻辑组合器：**

- **`.or`** —— 至少满足一个约束。
- **`.and`** —— 必须满足所有约束。

**附加：**

- **`.privateKeyUsage`** (iOS 9+) —— Secure Enclave 私钥操作（签名、密钥协商）所需。
- **`.applicationPassword`** (iOS 9+) —— 向密钥派生添加 App 提供的密码。非约束——附加加密层。

### 标志兼容性矩阵

| 标志                   | 后台工作？         | 典型配对                           | 误用时失败                           |
| ---------------------- | ------------------ | ---------------------------------- | ------------------------------------ |
| `.userPresence`        | 否                 | 前台 + `WhenUnlocked`              | 后台 `-25308`                        |
| `.biometryAny`         | 否                 | 前台密钥                           | 未注册生物识别时 `errSecAuthFailed`  |
| `.biometryCurrentSet`  | 否                 | 最高安全用 `WhenPasscodeSetTDO`    | 注册变更时认证失败                   |
| `.devicePasscode`      | 否                 | 合规流程                           | 无 UI 时 `-25308`                    |
| `.privateKeyUsage`     | 是（用于密钥操作） | Secure Enclave 密钥                | —                                    |
| `.applicationPassword` | 是（如果密码缓存） | 小众模型                           | 密码生命周期管理                     |

### 组合约束

由于 `SecAccessControlCreateFlags` 是 `OptionSet`，用数组字面量语法组合：

```swift
// 生物识别或密码——最常见模式
let flags: SecAccessControlCreateFlags = [.biometryCurrentSet, .or, .devicePasscode]

// 生物识别和密码——都要求（罕见，高安全）
let flags: SecAccessControlCreateFlags = [.biometryAny, .and, .devicePasscode]

// 生物识别或密码，加应用密码加密
let flags: SecAccessControlCreateFlags = [.biometryAny, .or, .devicePasscode, .applicationPassword]
```

> **关键规则：认证标志之间需要 `.or` / `.and`。** 不带逻辑运算符组合 `.biometryCurrentSet` 和 `.devicePasscode` 导致 `SecAccessControlCreateWithFlags` 返回 `nil` 和 `errSecParam` (-50)。两个来源都确认此行为。

---

## 基本规则：永不设置两个属性

`kSecAttrAccessible` 和 `kSecAttrAccessControl` 在查询字典中**互斥**。使用 `SecAccessControlCreateWithFlags` 时，可访问性级别通过 `protection` 参数嵌入 `SecAccessControl` 对象内部。在同一 `SecItemAdd` 查询中同时设置两者导致 **`errSecParam` (-50)**。

```swift
// ❌ 错误——设置可访问性两次，导致 errSecParam (-50)
var error: Unmanaged<CFError>?
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly, // ← 可访问性在此设置
    [.biometryCurrentSet, .or, .devicePasscode],
    &error
)!

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "credential",
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, // ❌ 冲突
    kSecAttrAccessControl as String: access, // ← 已包含可访问性
    kSecValueData as String: secretData
]
// SecItemAdd 返回 errSecParam (-50)
```

```swift
// ✅ 正确——可访问性仅在 SecAccessControl 内设置
var error: Unmanaged<CFError>?
guard let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.biometryCurrentSet, .or, .devicePasscode],
    &error
) else { throw KeychainError.accessControlCreationFailed(error?.takeRetainedValue()) }

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "credential",
    kSecAttrAccessControl as String: access, // 包含可访问性 + 认证标志
    kSecValueData as String: secretData
]
```

---

## 决策矩阵：选择正确的可访问性级别

### `WhenPasscodeSetThisDeviceOnly` —— 应该自毁的数据

用于最敏感的凭据。通过 `SecAccessControl` 与 `.biometryCurrentSet` 配对。接受权衡：条目在移除密码时永久销毁且永不在设备迁移后存活。你的 App **必须**优雅处理条目缺失并引导用户重新认证。

**用例：** 银行会话令牌、密码管理器保险库密钥、医疗凭据、E2E 加密私钥。

### `WhenUnlockedThisDeviceOnly` —— 标准设备绑定凭据

应该设备绑定但不需要密码删除行为的凭据。设备迁移后重新认证。

**用例：** OAuth 访问令牌（可刷新）、应用特定 API 密钥、缓存凭据、设备注册令牌。

### `AfterFirstUnlockThisDeviceOnly` —— 后台操作（服务最常见）

**任何由后台代码访问的 keychain 条目**的正确选择——推送通知处理器、WidgetKit 时间线提供者、后台获取、VPN 扩展、通知服务扩展。设备绑定。

**用例：** 推送通知解密密钥、VPN 凭据、后台同步令牌、watch 连接令牌。

### `AfterFirstUnlock` —— 后台 + 备份迁移

相同的后台可访问性，加条目随加密备份迁移。当同时需要后台访问和设备传输连续性时使用。

**用例：** 企业 VPN 凭据、邮件账户凭据、Wi-Fi 配置密码。

### 混合上下文的双条目策略

如果凭据同时需要后台访问（无 UI）和前台生物识别保护（带 UI），**存储两个独立条目**：一个带 `AfterFirstUnlockThisDeviceOnly` 的后台可用令牌（无 `SecAccessControl` 用户存在标志）和一个带 `WhenUnlockedThisDeviceOnly` + 生物识别 `SecAccessControl` 的更强仅前台条目。这避免了生物识别标志在后台可访问条目上的逻辑矛盾。

---

## 常见 AI 生成错误

### 错误 1：省略 `kSecAttrAccessible`（继承错误默认）

最普遍的错误。AI 代码生成器产生永不设置 `kSecAttrAccessible` 的 keychain 包装器，继承 `WhenUnlocked`。开发期间工作（测试时设备解锁），在后台扩展锁定时执行时生产失败——`errSecInteractionNotAllowed` (-25308)，经常静默吞噬。

```swift
// ❌ 错误——省略 kSecAttrAccessible，默认为 WhenUnlocked
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "authToken",
    kSecAttrService as String: "com.example.app",
    kSecValueData as String: tokenData
    // 缺少：kSecAttrAccessible——后台扩展将以 -25308 失败
]
```

```swift
// ✅ 正确——后台使用的显式可访问性
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "authToken",
    kSecAttrService as String: "com.example.app",
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    kSecValueData as String: tokenData
]
```

### 错误 2：使用废弃的 `kSecAttrAccessibleAlways`

iOS 12+ 编译带警告，运行时运行——可以说比硬失败更糟。无有意义的锁定状态保护。

```swift
// ❌ 错误——自 iOS 12 废弃
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccessible as String: kSecAttrAccessibleAlways, // ⚠️ 废弃
    kSecValueData as String: tokenData
]
// 替代：kSecAttrAccessibleAfterFirstUnlock
```

### 错误 3：不处理设备迁移后 `ThisDeviceOnly` 条目丢失

带 `ThisDeviceOnly` 的条目加密绑定到硬件 UID。它们排除在所有备份、iCloud 同步和 Quick Start 设备到设备迁移之外。恢复到新设备后，这些条目静默消失——`errSecItemNotFound` (-25300)。AI 生成的代码很少为此场景实现重新认证流程。

### 错误 4：后台可访问保护级别上的生物识别标志

设置 `.biometryCurrentSet` 与 `kSecAttrAccessibleAfterFirstUnlock` 在 API 级别技术上有效，但产生**逻辑矛盾**：`AfterFirstUnlock` 意味着锁定时后台访问，但生物识别认证需要交互式提示。结果：后台上下文中 `errSecInteractionNotAllowed`，击败目的。

### 错误 5：无逻辑运算符的冲突标志

不带 `.or` 或 `.and` 组合 `.biometryCurrentSet` 和 `.devicePasscode` 导致 `SecAccessControlCreateWithFlags` 返回 `nil` / `errSecParam` (-50)。

```swift
// ❌ 错误——缺少逻辑运算符
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlocked,
    [.biometryCurrentSet, .devicePasscode], // 缺少 .or 或 .and
    &error
)
// 返回 nil，错误包含 errSecParam
```

```swift
// ✅ 正确——约束间显式 .or
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlocked,
    [.biometryCurrentSet, .or, .devicePasscode],
    &error
)
```

---

## 代码模式

✅ 前两个示例是前台和后台访问的正确模式。第三个示例故意不正确。

### 带最高安全的生物识别保护

```swift
func saveBiometricProtectedItem(data: Data, account: String, service: String) throws {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        [.biometryCurrentSet, .or, .devicePasscode],
        &error
    ) else {
        throw KeychainError.accessControlCreationFailed(error?.takeRetainedValue())
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service,
        kSecAttrAccessControl as String: accessControl,
        kSecValueData as String: data
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    switch status {
    case errSecSuccess: return
    case errSecDuplicateItem:
        // 必须 delete + re-add：SecItemUpdate 无法更改 SecAccessControl
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let deleteStatus = SecItemDelete(searchQuery as CFDictionary)
        guard deleteStatus == errSecSuccess else {
            throw KeychainError.fromStatus(deleteStatus)
        }
        let readdStatus = SecItemAdd(query as CFDictionary, nil)
        guard readdStatus == errSecSuccess else {
            throw KeychainError.fromStatus(readdStatus)
        }
    default:
        throw KeychainError.fromStatus(status)
    }
}
```

> **重要：** `SecItemUpdate` **无法**更改现有条目上的 `SecAccessControl` 属性。要更改访问控制，必须删除并重新添加。两个来源都确认此。

### 后台可访问令牌（推送通知、VPN、小部件）

```swift
func saveBackgroundToken(_ token: Data, account: String, service: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        kSecValueData as String: token
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    switch status {
    case errSecSuccess: return
    case errSecDuplicateItem:
        let updateAttrs: [String: Any] = [kSecValueData as String: token]
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.fromStatus(updateStatus)
        }
    default:
        throw KeychainError.fromStatus(status)
    }
}
```

### 从后台扩展访问 `WhenUnlocked` 条目

```swift
// 在锁定时在 WidgetKit TimelineProvider 或 NotificationServiceExtension 中运行——将失败
func fetchTokenInBackground() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "authToken",
        kSecAttrService as String: "com.example.app",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
        // 条目用默认 WhenUnlocked 存储——锁定时不可访问
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    // 设备锁定时 status == errSecInteractionNotAllowed (-25308)
    guard status == errSecSuccess, let data = result as? Data else {
        return nil // ❌ 静默失败——无日志，无错误传播
    }
    return String(data: data, encoding: .utf8)
}
```

---

## macOS：`kSecUseDataProtectionKeychain`

macOS 有**两个 keychain 实现**（根据 TN3137）：遗留基于文件的 keychain（`~/Library/Keychains/login.keychain-db`）和现代数据保护 keychain。`SecItem` API 在 macOS 上默认为**遗留** keychain。

在每次 macOS keychain 查询中设置 `kSecUseDataProtectionKeychain: true` 以目标现代 keychain。没有它：

- `SecAccessControl` 标志以 `errSecParam` (-50) 失败
- iCloud Keychain 同步不工作
- Secure Enclave 集成不可用
- 生物识别保护（Touch ID）不工作

```swift
// ✅ macOS：始终包含 kSecUseDataProtectionKeychain
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: account,
    kSecAttrService as String: service,
    kSecUseDataProtectionKeychain as String: true, // ← macOS 上关键
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    kSecValueData as String: data
]
```

在 iOS、tvOS 和 watchOS 上，此标志被忽略（这些平台始终使用数据保护）。数据保护 keychain 需要用户登录上下文——在用户会话外运行的 `launchd` 守护进程必须使用遗留 keychain。Mac Catalyst 和 iOS-on-Mac App 自动使用数据保护。

---

## NSFileProtection 侧栏

keychain 和文件系统共享相同的数据保护架构但通过不同 API 暴露。使用 keychain 存储小的离散密钥（密码、令牌、密钥）。使用 `NSFileProtection` 存储较大数据（文档、数据库、图像）。

**`NSFileProtectionComplete`** (Class A) = `kSecAttrAccessibleWhenUnlocked`。文件锁定时不可访问。类别密钥锁定后约 10 秒丢弃。

**`NSFileProtectionCompleteUnlessOpen`** (Class B) = **无 keychain 等效。** 使用非对称 ECDH (Curve25519) 允许已打开文件在锁定时继续写入。为后台下载设计（如邮件附件下载继续写入已打开文件）。

**`NSFileProtectionCompleteUntilFirstUserAuthentication`** (Class C) = `kSecAttrAccessibleAfterFirstUnlock`。未显式设置保护时第三方 App 文件的默认值。首次解锁后可用。

**`NSFileProtectionNone`** (Class D) = 废弃的 `kSecAttrAccessibleAlways`。仅受设备 UID 保护。

**推荐的分层方法：** 将加密密钥存储在 keychain 中带 `WhenUnlockedThisDeviceOnly`，然后用这些密钥用 `NSFileProtectionComplete` 加密磁盘上的较大文件作为附加层。

---

## 错误码参考

| 代码       | 常量                          | 含义                              | 常见根本原因                                                                                                                                   |
| ---------- | ----------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **-25308** | `errSecInteractionNotAllowed` | 条目在当前状态不可访问            | 设备锁定 + `WhenUnlocked` 条目；BFU 状态 + `AfterFirstUnlock` 条目；后台中的生物识别标志                                              |
| **-50**    | `errSecParam`                 | 无效参数                          | 同时设置 `kSecAttrAccessible` 和 `kSecAttrAccessControl`；无 `.or`/`.and` 的冲突标志；macOS 上缺少 `kSecUseDataProtectionKeychain` |
| **-25293** | `errSecAuthFailed`            | 认证失败                          | 生物识别认证失败；带 `.biometryCurrentSet` 的注册变更；未注册生物识别                                                                |
| **-25300** | `errSecItemNotFound`          | 条目不在 keychain 中              | 条目从未存储；迁移后丢失 `ThisDeviceOnly`；移除密码时删除 `WhenPasscodeSet`                                                          |
| **-25299** | `errSecDuplicateItem`         | 条目已存在                        | 存在匹配主键时 `SecItemAdd`——使用 add-or-update 模式                                                                               |
| **-128**   | `errSecUserCanceled`          | 用户取消提示                      | 用户在生物识别/密码对话框点击取消                                                                                                   |
| **-34018** | `errSecMissingEntitlement`    | 缺少权限                          | keychain 访问组不在权限中；iOS Simulator 上常见                                                                                     |

最阴险的是 `-25308`——它在生产中出现但在开发期间很少出现，因为开发者用解锁设备测试。始终通过推迟操作并在 `UIApplication.shared.isProtectedDataAvailable` 为 `true` 时重试来处理它。

---

## iOS 版本时间线

**iOS 8 (2014)：** 引入 `WhenPasscodeSetThisDeviceOnly`。添加 `SecAccessControlCreateWithFlags`。`.userPresence` 标志。

**iOS 9 (2015)：** 添加 `.devicePasscode`、`.applicationPassword`、`.privateKeyUsage` 标志。Apple 在 WWDC 2015 Session 706 宣布废弃 `Always` 的意图。

**iOS 11.3 (2018)：** `.touchIDAny` → `.biometryAny`；`.touchIDCurrentSet` → `.biometryCurrentSet`（Face ID 的统一命名）。

**iOS 12 (2018)：** `kSecAttrAccessibleAlways` 和 `AlwaysThisDeviceOnly` 正式废弃。两者仍编译和运行以向后兼容。

**iOS 15 (2021)：** MDM 安装的 keychain 条目将默认从"始终"更改为"首次解锁后，不可迁移"。App 预热可能在首次解锁前启动进程，使 `AfterFirstUnlock` 条目暂时不可用。

**iOS 16 (2022)：** 启动 Passkey（通过 E2E 加密 iCloud Keychain 同步的 FIDO2/WebAuthn 密钥对）。访问控制 API 无变化。

**iOS 17 (2023)：** 企业 passkey 支持。无 `kSecAttrAccessible` 或 `SecAccessControl` 变化。

**iOS 18 (2024)：** 独立 Passwords App。无 keychain 数据保护 API 变化。

**iOS 26 (2025)：** 默认启用设备被盗保护——在离开熟悉位置时要求生物识别认证（无密码回退）用于存储的密码。通过 FIDO Alliance 标准安全 passkey 导入/导出。无 `kSecAttrAccessible` 常量变化。

---

## 测试要求

所有数据保护测试**必须**使用启用密码的物理设备。iOS Simulator 不强制 `kSecAttrAccessible` 或 `NSFileProtection`，产生虚假的安全感。

**关键测试场景：**

1. **重启 / BFU 状态：** 重启设备，解锁前尝试 keychain 访问。`AfterFirstUnlock` 条目应返回 `-25308` 或 `-25300`。解锁一次，再次锁定，测试后台访问——应成功。

2. **锁定时序：** 存储 `WhenUnlocked` 条目。锁定设备。立即尝试读取——预期 `-25308`。

3. **移除密码：** 存储 `WhenPasscodeSetThisDeviceOnly` 条目。在设置中移除密码。验证条目被删除（`-25300`）。

4. **生物识别注册变更：** 存储 `.biometryCurrentSet` 条目。添加新指纹或 Face ID 外观。验证认证失败（`-25293`）。

5. **备份/恢复迁移：** 备份设备，恢复到不同物理设备。验证所有 `ThisDeviceOnly` 条目缺失（`-25300`）。

6. **后台扩展访问：** 设备锁定时触发生成通知服务扩展或小部件时间线更新。验证 `AfterFirstUnlock` 条目可读且 `WhenUnlocked` 条目不可。

---

## 交叉引用

- `keychain-fundamentals.md` —— SecItem CRUD 模式、add-or-update、OSStatus 处理
- `biometric-authentication.md` —— 生物识别标志选择（`.biometryCurrentSet`、`.biometryAny`、`.userPresence`）和 keychain 绑定模式
- `secure-enclave.md` —— 带 `SecAccessControl` 和 `.privateKeyUsage` 的硬件支持密钥
- `keychain-item-classes.md` —— 类别特定可访问性考虑和主键组合
- `common-anti-patterns.md` —— 反模式 #5（缺少 `kSecAttrAccessible`）、#3（仅 LAContext 门）
- `compliance-owasp-mapping.md` —— M9（不安全数据存储）可访问性要求

---

## 总结清单

1. **始终显式设置 `kSecAttrAccessible`** —— 永不依赖 `WhenUnlocked` 默认；选择匹配你访问上下文的级别（前台 vs 后台）
2. **永不在同一查询字典中同时设置 `kSecAttrAccessible` 和 `kSecAttrAccessControl`** —— 可访问性属于 `SecAccessControlCreateWithFlags` 内部
3. **为任何由后台扩展、小部件、VPN 或推送通知处理器访问的条目使用 `AfterFirstUnlockThisDeviceOnly`**
4. **将 `WhenPasscodeSetThisDeviceOnly` 与 `.biometryCurrentSet` 配对** 用于最高安全条目，并优雅处理移除密码时的条目删除
5. **组合多个认证标志时包含 `.or` 或 `.and`** —— 省略运算符导致 `errSecParam` (-50)
6. **在所有 macOS keychain 查询上设置 `kSecUseDataProtectionKeychain: true`** 以目标现代数据保护 keychain
7. **为实现设备迁移或备份恢复后缺失的 `ThisDeviceOnly` 条目实现重新认证流程**
8. **在 App 启动路径的 keychain 访问前检查 `isProtectedDataAvailable`** —— iOS 15+ 预热可能在首次解锁前启动你的进程
9. **更改现有条目上的 `SecAccessControl` 时删除并重新添加**（而非更新）—— `SecItemUpdate` 无法修改访问控制属性
10. **在物理设备上跨锁定/解锁、重启、移除密码和生物识别注册变更场景测试** —— Simulator 不强制数据保护
11. **在 CI/CD linting 中阻止废弃的 `kSecAttrAccessibleAlways` 常量** 并在下次前台认证时将现有条目迁移到 `AfterFirstUnlock`
