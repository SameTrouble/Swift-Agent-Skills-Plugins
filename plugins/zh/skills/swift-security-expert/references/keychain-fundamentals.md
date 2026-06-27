# Keychain 基础

> **范围：** SecItem\* CRUD 操作、查询字典结构、kSecClass 类型、OSStatus 错误处理、基于 actor 的包装器模式。这是基础文件——所有其他参考文件都假设熟悉这些模式。
>
> **关键 API：** `SecItemAdd`、`SecItemCopyMatching`、`SecItemUpdate`、`SecItemDelete`、`kSecClassGenericPassword`、`kSecClassInternetPassword`、`kSecClassKey`、`kSecClassCertificate`、`kSecClassIdentity`
>
> **Apple 文档：** [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)、[TN3137](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)、Quinn "The Eskimo!" DTS 帖子："SecItem: Fundamentals" 和 "SecItem: Pitfalls and Best Practices"

---

## 架构概述

Keychain Services API 暴露四个映射到数据库 CRUD 操作的 C 函数。每个调用都是到 `securityd` 守护进程的 IPC 往返，由加密 SQLite 数据库支持。这意味着每个调用都**阻塞调用线程**，永不能在 `@MainActor` 上执行。

内部，keychain 条目使用**双层 AES-256-GCM 加密**（根据 Apple Platform Security Guide）：表级**元数据密钥**缓存在应用处理器中用于快速属性搜索，和**每行密钥密钥**需要 Secure Enclave 往返以解密 `kSecValueData`。此双层设计有下面性能章节涵盖的直接性能影响。

---

## 四个函数及其字典契约

每个函数接受特定_类型_的字典。混淆哪些键属于哪个字典是 bug 的最常见单一来源。Quinn（Apple DTS）定义了五个属性组：

1. **条目类别** —— `kSecClass`
2. **条目属性** —— `kSecAttrAccount`、`kSecAttrService` 等
3. **搜索属性** —— `kSecMatchLimit`
4. **返回类型属性** —— `kSecReturnData`、`kSecReturnAttributes`、`kSecReturnRef`、`kSecReturnPersistentRef`
5. **值类型属性** —— `kSecValueData`、`kSecValueRef`

| 函数                            | 字典类型                                      | 支持返回键？         | 默认 `kSecMatchLimit`   | 自      |
| ------------------------------- | --------------------------------------------- | -------------------- | ------------------------ | ------- |
| `SecItemAdd(_:_:)`              | 添加字典（类别 + 属性 + 值）                  | ✅ 可选              | N/A                      | iOS 2.0 |
| `SecItemCopyMatching(_:_:)`     | 查询 + 返回（全部 5 组）                      | ✅ 结果所需          | `kSecMatchLimitOne`      | iOS 2.0 |
| `SecItemUpdate(_:_:)`           | 纯查询（参数 1）+ 更新字典（参数 2）          | ❌                   | **`kSecMatchLimitAll`**  | iOS 2.0 |
| `SecItemDelete(_:)`             | 纯查询                                        | ❌                   | **`kSecMatchLimitAll`**  | iOS 2.0 |

**关键细节：** `kSecMatchLimit` 对 `SecItemCopyMatching` 默认为 `kSecMatchLimitOne`，但对 `SecItemUpdate` 和 `SecItemDelete` 默认为 **`kSecMatchLimitAll`**。不充分的删除查询将清除 keychain 中每个匹配条目。

**字典卫生：** 每次调用使用新字典。将 `kSecReturnData` 放在添加字典中或将 `kSecClass` 放在更新字典中会产生 `errSecParam` (-50)。Quinn 的指导："每次调用使用新字典。这防止一次调用的状态意外泄漏到后续调用。"

---

## 唯一性和主键

对于 `kSecClassGenericPassword`，唯一性由以下组合确定：

- `kSecAttrAccount` + `kSecAttrService` + `kSecAttrAccessGroup` + `kSecAttrSynchronizable`

其他属性如 `kSecAttrGeneric`、`kSecAttrLabel` 或 `kSecAttrDescription` **不参与唯一性**。这意味着在非唯一属性上过滤的查询可能返回 `errSecItemNotFound`，而后续添加仍命中 `errSecDuplicateItem`。

对于 `kSecClassInternetPassword`，唯一性集包括：`kSecAttrAccount` + `kSecAttrServer` + `kSecAttrProtocol` + `kSecAttrAuthenticationType` + `kSecAttrPort` + `kSecAttrPath` + `kSecAttrSecurityDomain` + `kSecAttrAccessGroup` + `kSecAttrSynchronizable`。

**不可变属性：** `kSecAttrAccount` 和 `kSecClass` 不能通过 `SecItemUpdate` 更改。要更改它们，删除并重新添加条目（见 `keychain-item-classes.md`）。

---

## Add-or-Update 模式

最常见的 AI 生成 keychain bug 是调用 `SecItemAdd` 不处理 `errSecDuplicateItem` (-25299)。

❌ **重复时静默失败的朴素添加：**

```swift
// ❌ 错误——如果条目已存在则静默失败
func savePassword(_ password: String, account: String) {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.example.app",
        kSecAttrAccount: account,
        kSecValueData: Data(password.utf8)
    ]
    SecItemAdd(query as CFDictionary, nil)  // 返回值被忽略！
    // 如果条目存在 → errSecDuplicateItem (-25299)——密码从未保存
}
```

✅ **带穷尽 OSStatus 处理的正确 add-or-update：**

```swift
// ✅ 正确——尝试添加，重复时回退到更新
func savePassword(_ password: String, account: String) throws {
    let baseQuery: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.example.app",
        kSecAttrAccount: account
    ]

    var addQuery = baseQuery
    addQuery[kSecValueData] = Data(password.utf8)
    addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

    switch addStatus {
    case errSecSuccess:
        return

    case errSecDuplicateItem:
        // 条目存在——更新它
        let updates: [CFString: Any] = [kSecValueData: Data(password.utf8)]
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            updates as CFDictionary
        )
        guard updateStatus == errSecSuccess else {
            throw KeychainError(status: updateStatus)
        }

    case errSecInteractionNotAllowed:
        // 设备锁定——不要 delete-and-retry！
        throw KeychainError(status: addStatus)

    default:
        throw KeychainError(status: addStatus)
    }
}
```

此模式的关键点：

- **添加 vs 更新使用独立字典**——更新字典只包含要更改的属性，永不含 `kSecClass` 或搜索属性。
- **`errSecInteractionNotAllowed`** (-25308) 意味着设备锁定且数据保护阻止访问。永不要响应此错误删除条目；条目有效但暂时不可访问。
- **优先更新而非 delete-then-add**——更新保留持久引用并避免删除和添加之间的竞争条件窗口。

---

## 从 Keychain 读取：返回标志和类型转换

第二个最常见 bug 是不带 `kSecReturn*` 标志调用 `SecItemCopyMatching`。函数可能返回 `errSecSuccess` 和 `nil` 结果——这是"成功但 nil"，非真正成功。

❌ **因缺少 `kSecReturnData` 返回无数据的查询：**

```swift
// ❌ 错误——无 kSecReturn* 标志，结果始终为 nil
func loadPassword(account: String) -> Data? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.example.app",
        kSecAttrAccount: account,
        kSecMatchLimit: kSecMatchLimitOne
        // BUG：缺少 kSecReturnData: true
    ]
    var result: CFTypeRef?
    SecItemCopyMatching(query as CFDictionary, &result)
    return result as? Data  // 始终 nil——未请求返回类型
}
```

✅ **带正确返回标志和穷尽错误处理的查询：**

```swift
// ✅ 正确——显式请求数据，处理所有错误状态
func loadPassword(account: String) throws -> Data? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.example.app",
        kSecAttrAccount: account,
        kSecMatchLimit: kSecMatchLimitOne,
        kSecReturnData: true  // ← 获取密钥所需
    ]

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
        guard let data = result as? Data else {
            throw KeychainError(status: errSecParam)
        }
        return data

    case errSecItemNotFound:
        return nil  // 合法"未找到"——非错误

    case errSecInteractionNotAllowed:
        throw KeychainError(status: status)

    default:
        throw KeychainError(status: status)
    }
}
```

### 返回类型速查表

`CFTypeRef` 类型完全取决于设置了哪些返回标志和匹配限制：

```text
仅 kSecReturnData     + kSecMatchLimitOne  → Data
kSecReturnAttributes  + kSecMatchLimitOne  → [String: Any]
kSecReturnData + 属性 + kSecMatchLimitOne  → [String: Any]  （数据在 kSecValueData 键下）
kSecReturnRef          + kSecMatchLimitOne  → SecKey / SecCertificate / SecIdentity
kSecReturnPersistentRef + kSecMatchLimitOne → Data（不透明句柄）
任何组合              + kSecMatchLimitAll  → 上述类型的数组
```

**注意：** 将 `kSecReturnData` 与 `kSecMatchLimitAll` 组合在某些 OS 版本上可能对密码类别受限。对于列出条目，优先使用带 `kSecMatchLimitAll` 的 `kSecReturnAttributes` 或 `kSecReturnRef`，然后按需逐条目获取数据。

### 字符串键 vs kSec\* 常量

永不要使用原始字符串字面量（`"svce"`、`"class"`）而非 `kSec*` 常量。常量是带特定内部表示的 `CFString` 值。存在两种同样有效的字典键样式：

```swift
// 样式 A：CFString 键（定义时更少转换，调用点转换一次）
let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword]
SecItemAdd(query as CFDictionary, nil)

// 样式 B：String 键（社区代码中更常见）
let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
SecItemAdd(query as CFDictionary, nil)
```

两者都正确。选择一种样式并在代码库中一致使用。

---

## 集中式查询构建器

两个研究来源都建议集中查询构造以防止标志遗漏和键拼写错误：

```swift
enum KeychainQueryBuilder {
    static func buildQuery(
        forClass secClass: CFString = kSecClassGenericPassword,
        account: String? = nil,
        service: String? = nil,
        accessGroup: String? = nil,
        returnData: Bool = false,
        returnAttributes: Bool = false,
        matchLimit: CFString = kSecMatchLimitOne
    ) -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: secClass]

        if let account  { query[kSecAttrAccount as String] = account }
        if let service  { query[kSecAttrService as String] = service }
        if let group    = accessGroup { query[kSecAttrAccessGroup as String] = group }
        if returnData   { query[kSecReturnData as String] = kCFBooleanTrue! }
        if returnAttributes { query[kSecReturnAttributes as String] = kCFBooleanTrue! }
        query[kSecMatchLimit as String] = matchLimit

        return query
    }
}
```

此模式确保返回标志被有意设置，并提供单一审计查询构造的站点。

---

## OSStatus 错误处理

永不要将所有非零 `OSStatus` 值视为致命错误。几个代码代表预期操作状态：

| OSStatus 代码 | 常量                          | 含义                                            | 正确响应                           |
| ------------- | ----------------------------- | ----------------------------------------------- | ---------------------------------- |
| `0`           | `errSecSuccess`               | 操作成功                                        | 正常继续                           |
| `-25299`      | `errSecDuplicateItem`         | 条目已存在（添加时）                            | 回退到 `SecItemUpdate`             |
| `-25300`      | `errSecItemNotFound`          | 未找到匹配条目                                  | 返回 `nil` / 删除时视为成功        |
| `-25308`      | `errSecInteractionNotAllowed` | 设备锁定，数据保护激活                          | 稍后重试——**永不删除**             |
| `-25293`      | `errSecUserCanceled`          | 用户取消生物识别提示                            | 将取消传播到 UI                    |
| `-50`         | `errSecParam`                 | 无效参数 / 错误字典键                           | 开发者错误——修复查询              |
| `-25244`      | `errSecNoSuchAttr`            | 不支持属性（数据保护 keychain）                 | 检查不支持的属性                   |

将原始代码映射到领域特定 Swift 错误：

```swift
struct KeychainError: Error, CustomStringConvertible {
    let status: OSStatus

    var description: String {
        let msg = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"
        return "KeychainError(\(status)): \(msg)"
    }
}
```

**日志安全：** 仅记录查询形状和结果状态码。永不记录密钥数据（`kSecValueData`）、令牌或密钥。

---

## Actor 隔离的 Keychain 管理器 (iOS 17+ / macOS 14+)

每个 `SecItem*` 函数都因到 `securityd` 的 IPC 和潜在 Secure Enclave 往返而阻塞调用线程。对于生物识别保护的条目，阻塞可能持续用户认证期间的几秒（WWDC 2014 Session 711）。

❌ **阻塞 UI 的 @MainActor keychain 访问：**

```swift
// ❌ 错误——阻塞主线程，securityd IPC 期间冻结 UI
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var token: String = ""

    func loadToken() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.example.app",
            kSecAttrAccount: "authToken",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            self.token = String(data: data, encoding: .utf8) ?? ""
        }
        // securityd IPC + 潜在 SE 往返期间 UI 冻结
    }
}
```

✅ **带完整 CRUD 的 actor 隔离 keychain 管理器：**

```swift
// ✅ 正确——专用 actor 将所有 SecItem 调用移出 @MainActor
actor KeychainManager {
    static let shared = KeychainManager()

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "default") {
        self.service = service
    }

    // MARK: - 保存（add-or-update）

    func save(_ data: Data, for key: String,
              accessibility: CFTypeRef = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) throws {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = accessibility

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updates: [CFString: Any] = [kSecValueData: data]
            let updateStatus = SecItemUpdate(
                baseQuery as CFDictionary,
                updates as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError(status: updateStatus)
            }
        case errSecInteractionNotAllowed:
            throw KeychainError(status: addStatus)
        default:
            throw KeychainError(status: addStatus)
        }
    }

    // MARK: - 加载

    func load(for key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecInteractionNotAllowed:
            throw KeychainError(status: status)
        default:
            throw KeychainError(status: status)
        }
    }

    // MARK: - 删除（幂等）

    func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    // MARK: - 列出所有账户（仅属性——快速）

    func allAccounts() throws -> [String] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true  // 无 kSecReturnData → 跳过 SE 往返
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let items = result as? [[String: Any]] else { return [] }
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw KeychainError(status: status)
        }
    }
}
```

**从 SwiftUI 调用：**

```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false

    func loadToken() async {
        do {
            // 跨越 actor 边界——挂起，不阻塞 MainActor
            let data = try await KeychainManager.shared.load(for: "authToken")
            isAuthenticated = data != nil
        } catch {
            isAuthenticated = false
        }
    }
}
```

### 为什么 Actor 优于 GCD

| 维度             | Actor (iOS 17+)                   | GCD 串行队列                        |
| ---------------- | --------------------------------- | ----------------------------------- |
| UI 阻塞          | 低——编译器强制隔离                 | 低（如果正确分发）                  |
| 线程安全         | 由 actor 运行时序列化              | 手动——开发者纪律                    |
| 可读性           | 线性 async/await                   | 嵌套完成处理器                      |
| 编译器保证       | 强制 `Sendable` + 隔离             | 无——可能静默数据竞争                |
| Swift 6 兼容性   | 原生——actor 是 `Sendable`          | 需要手动 `@Sendable` 注解           |

### 遗留 GCD 模式（iOS 13–16 代码库）

```swift
class LegacyKeychainManager {
    private let queue = DispatchQueue(label: "com.app.keychain",
                                      qos: .userInitiated)

    func load(key: String, completion: @escaping (Result<Data?, Error>) -> Void) {
        queue.async {
            // ... 在后台队列上 SecItemCopyMatching ...
            DispatchQueue.main.async { completion(result) }
        }
    }
}
```

---

## 性能架构

### 双层加密和查询成本

由于双层加密设计：

- **仅 `kSecReturnAttributes`** → 使用缓存的元数据密钥 → **快速**（无 Secure Enclave 往返）
- **`kSecReturnData`** → 需要 Secure Enclave 的每行密钥密钥 → **较慢**

对于列出操作，始终使用 `kSecReturnAttributes` 或 `kSecReturnRef`，仅对用户选择的特定条目获取密钥数据。

### 查询特异性

底层 SQLite 数据库受益于窄约束。仅指定 `kSecClass: kSecClassGenericPassword` 和 `kSecMatchLimitAll` 的查询执行**全表扫描**。添加 `kSecAttrService` 和 `kSecAttrAccount` 启用索引查找。始终在生产查询中包含所有相关唯一性属性。

### App 启动性能

App 启动期间的 keychain 访问是可衡量的性能风险：

- 每次调用需要到 `securityd` 的 IPC 加上潜在 Secure Enclave 延迟
- 带 `kSecAttrAccessibleWhenUnlocked` 的条目可能在首次解锁前不可用（iOS 可能在用户解锁前启动 App——如后台刷新、VoIP 推送）
- **最佳实践：** 推迟 keychain 读取直到实际需要。永不在 `application(_:didFinishLaunchingWithOptions:)` 中同步调用 SecItem。
- 优雅处理 `errSecInteractionNotAllowed`——永不破坏性。

### 批量操作

SecItem **没有批量 API**。每个函数单独操作，有一个部分例外：`SecItemAdd` 支持 `kSecUseItemList` 在单次调用中添加多个证书或密钥（非密码）。对于批量读取，带 `kSecMatchLimitAll` 的 `SecItemCopyMatching` 一次检索所有匹配条目。

---

## macOS Keychain 路由 (TN3137)

在 macOS 上，SecItem API 可以目标两种不同实现：

| 实现                 | 激活方式                                                                           | 行为                                                                                                             |
| -------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **遗留基于文件的 keychain** | macOS 默认（未选择加入）                                                           | 静默忽略不支持的属性；不一致的 `kSecMatchLimit` 默认值；不同的 `SecItemAdd` 返回类型                             |
| **数据保护 keychain** | `kSecUseDataProtectionKeychain: true` (macOS 10.15+) 或 `kSecAttrSynchronizable: true` | 与 iOS 对等；iCloud Keychain 同步、生物识别保护和 Secure Enclave 密钥存储所需                                     |

**现代 App 必须始终以数据保护 keychain 为目标。** Mac Catalyst 和 iOS Apps on Mac 自动使用它。

```swift
// macOS：始终选择加入数据保护 keychain
var query: [CFString: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "com.example.app",
    kSecAttrAccount: "token"
]
#if os(macOS)
query[kSecUseDataProtectionKeychain] = true
#endif
```

基于文件的 keychain 的垫片层有文档记录的 bug——它静默忽略不支持的属性，而数据保护 keychain 正确返回 `errSecNoSuchAttr` (-25244)。在 macOS 上调试 keychain 问题通常从确认使用哪个实现开始。

---

## 可访问性和数据保护类别

`kSecAttrAccessible` 属性控制何时可以解密 keychain 条目的密钥数据。此处为简要指导；完整覆盖见 `keychain-access-control.md`。

| 常量                                               | 何时可用                   | 在备份中存活？ | 用例                                     |
| -------------------------------------------------- | -------------------------- | -------------- | ---------------------------------------- |
| `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`     | 解锁后，直到锁定           | 否（仅设备）   | 大多数密钥的默认                         |
| `kSecAttrAccessibleAfterFirstUnlock`               | 首次解锁后直到重启         | 是             | 后台处理令牌                             |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`  | 仅设置密码 + 解锁时        | 否             | 最高敏感度数据（OWASP 推荐）             |
| `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | 首次解锁后直到重启         | 否             | 后台 + 仅设备                            |

**废弃：** `kSecAttrAccessibleAlways`——iOS 12 废弃，Apple Silicon Mac 上不支持。永不使用。

---

## 交叉引用

- **条目类别深入**（每个 kSecClass 的必需 vs 可选属性）→ `keychain-item-classes.md`
- **访问控制标志和 SecAccessControl** → `keychain-access-control.md`
- **生物识别门控的 keychain 访问**（LAContext 集成）→ `biometric-authentication.md`
- **Secure Enclave 密钥存储** → `secure-enclave.md`
- **凭据生命周期模式**（OAuth 令牌、API 密钥）→ `credential-storage-patterns.md`
- **访问组和共享** → `keychain-sharing.md`
- **测试 keychain 代码**（mock、CI/CD）→ `testing-security-code.md`
- **常见反模式**（综合目录）→ `common-anti-patterns.md`

---

## 权威参考

| 来源                                                                                                                          | 相关性                                          |
| ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)                                       | 主 API 着陆页                                    |
| [TN3137: On Mac Keychain APIs and Implementations](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains) | macOS 数据保护 vs 基于文件的路由                 |
| Quinn "The Eskimo!" — "SecItem: Fundamentals" / "SecItem: Pitfalls and Best Practices"                                          | 最实用的 DTS 参考，更新至 2025 年                |
| [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web) — Keychain Data Protection 章节        | 双层加密架构                                     |
| WWDC 2014 Session 711 — "Keychain and Authentication with Touch ID"                                                             | Touch ID/keychain 集成模式                       |
| WWDC 2019 Session 516 — "What's New in Authentication"                                                                          | 现代凭据管理                                     |

---

## 研究来源间的矛盾

在交叉验证研究输入期间，注意到以下差异：

1. **字典键类型约定：** Claude 来源使用 `[CFString: Any]`；并行来源使用 `[String: Any]` 带 `kSec* as String` 转换。**解决：** 两者都正确。`[CFString: Any]` 样式略简洁；`[String: Any]` 样式在社区代码中更常见。本文件使用 `[CFString: Any]` 以简洁但在字符串键章节展示两种样式。

2. **默认可访问性推荐：** Claude 来源引用 OWASP 推荐高敏感数据使用 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`；并行来源默认 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。**解决：** 两者对不同威胁模型有效。`WhenPasscodeSet` 最强但用户移除密码时条目被删除。`WhenUnlockedThisDeviceOnly` 是仅前台访问的安全通用默认。actor 管理器示例使用 `AfterFirstUnlockThisDeviceOnly` 以后台兼容同时保持设备绑定。

3. **`kSecReturnData` + `kSecMatchLimitAll` 限制：** 并行来源声称此组合对密码类别受限。Claude 来源未提及。**解决：** 此限制在某些 OS 版本 / keychain 实现中存在。最安全做法是使用 `kSecReturnRef` 或 `kSecReturnAttributes` 与 `LimitAll`，然后逐条目获取数据。在返回类型速查表中注明。

---

## 总结清单

发布 keychain 代码前，验证：

1. **每个调用都检查 OSStatus** —— 穷尽 `switch` 至少覆盖 `errSecSuccess`、`errSecDuplicateItem`、`errSecItemNotFound`、`errSecInteractionNotAllowed`；无忽略返回值
2. **实现 add-or-update 模式** —— `SecItemAdd` 捕获 `-25299` 并回退到 `SecItemUpdate`；重复保存永不崩溃或静默失败
3. **显式设置返回标志** —— 每个 `SecItemCopyMatching` 调用包含至少一个 `kSecReturn*` 标志；无"成功但 nil"bug
4. **CFTypeRef 转换匹配标志** —— 转换类型对应返回标志和匹配限制的组合（见返回类型速查表）
5. **@MainActor 上零 SecItem 调用** —— 所有 keychain 访问隔离在专用 `actor` (iOS 17+) 或串行 `DispatchQueue` (iOS 13–16)
6. **每次调用使用新字典** —— 无跨 SecItem 函数的字典重用；添加字典、查询字典和更新字典独立
7. **使用 kSec\* 常量** —— 字典键无原始字符串字面量；使用 `[CFString: Any]` 或带 `as String` 转换的 `[String: Any]`
8. **查询具体** —— GenericPassword 包含 `kSecAttrService` + `kSecAttrAccount`；除非需要枚举否则使用 `kSecMatchLimitOne`
9. **删除将未找到视为成功** —— 删除时 `errSecItemNotFound` 是有效后置条件，非错误
10. **macOS 以数据保护 keychain 为目标** —— macOS 目标设置 `kSecUseDataProtectionKeychain: true`（Catalyst/iOS-on-Mac 自动）
11. **非破坏性处理 errSecInteractionNotAllowed** —— 设备锁定状态触发稍后重试逻辑，永不 delete-and-recreate
