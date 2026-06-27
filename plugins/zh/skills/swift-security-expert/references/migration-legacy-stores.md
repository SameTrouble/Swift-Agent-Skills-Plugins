# 迁移和遗留存储

> **范围：** 将敏感数据从 UserDefaults、plist、NSCoding 归档和其他不安全存储迁移到 Apple Keychain Services。涵盖遗留数据的安全删除、首次启动 keychain 清理、版本化迁移模式和 Team ID 转移边缘情况。
>
> **适用于：** iOS 15+（actor 支持、预热）、iOS 17+（推荐部署目标）
>
> **交叉引用：** `keychain-fundamentals.md`（SecItem CRUD）、`keychain-access-control.md`（可访问性类别）、`common-anti-patterns.md`（UserDefaults 密钥反模式）、`credential-storage-patterns.md`（迁移后令牌生命周期）、`testing-security-code.md`（基于协议的 mock）

---

## 为什么迁移 — 遗留存储的风险

UserDefaults、`.plist` 文件和 NSCoding 归档在 App 沙箱内以未加密明文存储数据。此数据在越狱设备上可读并包含在未加密的 iTunes/Finder 备份中——任何有备份访问权限的人都可以提取令牌、密码和 PII。OWASP 将不安全数据存储列为前 10 移动风险（M9）。

| 存储             | 静态加密          | 在备份中                         | 卸载后存活 | 适合密钥 |
| ---------------- | ----------------- | -------------------------------- | ---------- | -------- |
| UserDefaults     | 否                | 是                               | 否         | **否**   |
| .plist 文件      | 否（默认）        | 是                               | 否         | **否**   |
| NSCoding 归档    | 否（默认）        | 是                               | 否         | **否**   |
| Keychain         | 是（AES-256-GCM） | `ThisDeviceOnly` 变体排除        | **是**     | **是**   |

Keychain 条目由 `securityd` 守护进程管理，用由 Secure Enclave 保护的每行密钥加密，并与 App 沙箱隔离。这是 Apple 平台上令牌、密码、API 密钥和 PII 的唯一合适位置。

---

## 五个正确性陷阱

大多数 AI 生成的迁移代码包含至少一个这些错误。每个通过测试但在生产中灾难性失败。

**陷阱 1 — 遗留数据在迁移后存活。** 调用 `UserDefaults.standard.removeObject(forKey:)` 从内存缓存和 plist 文件移除键值对，但不安全覆盖 NAND 闪存。然而，iOS 通过_加密擦除_实现安全删除：每个文件有每文件 AES-256 密钥，标准删除 API 通过 Effaceable Storage 销毁该密钥，使物理位永久不可访问。真正的风险向量是迁移完成前创建的**未加密备份**——plist 留在磁盘上直到文件系统回收空间。**始终在验证 keychain 写入后显式删除所有遗留键。**

**陷阱 2 — Keychain 条目在 App 删除后存活。** 当用户卸载你的 App 时，UserDefaults 和沙箱文件被清除，但 keychain 条目无限期持久。Apple 在 iOS 10.3 beta 中尝试更改但因兼容性问题回滚。重新安装时，陈旧 keychain 条目（旧令牌、过期凭据、过时 schema）导致静默认证失败或——更糟——恢复_先前用户_的会话。

**陷阱 3 — 迁移在每次启动时运行。** 每次启动检查 UserDefaults 中的遗留数据浪费周期并在 iOS 15+ App 预热期间有数据丢失风险。当系统在设备解锁前预热你的进程时，`UserDefaults` 可能返回空值（加密 plist 不可访问）。将空结果解释为"无内容迁移"的迁移会跳过真实数据或用 nil 覆盖有效 keychain 条目。

**陷阱 4 — 非原子迁移使数据处于悬空状态。** 写入 keychain 然后从 UserDefaults 删除作为两个独立操作创造失败窗口。如果 App 在写入和删除之间被杀——或 keychain 写入静默失败——用户完全丢失数据。

**陷阱 5 — 更改 `kSecAttrService` 或 `kSecAttrAccount` 孤立现有条目。** 这些属性形成 `kSecClassGenericPassword` 的主键。在新版本中更改任一不更新现有条目——它创建新的。旧条目成为浪费 keychain 空间并在意外上下文中导致 `errSecDuplicateItem` 的不可见孤立体。关键是，`SecItemUpdate` **无法更改主键属性**——调用会出错。必须执行完整 rekey 迁移：读旧 → 写新 → 验证 → 删旧。

---

## 首次启动 Keychain 清理

持久性不对称（UserDefaults 卸载时删除，keychain 不删除）启用可靠的重装检测器。此模式**必须在任何其他 keychain 或 SDK 初始化之前运行**——Firebase、分析和认证库都在设置期间读取 keychain 条目。

```swift
// ✅ 正确：带受保护数据保护的首次启动清理
// iOS 15+ 需要 isProtectedDataAvailable / 预热行为

actor FirstLaunchGuard {
    static let shared = FirstLaunchGuard()
    private let hasRunKey = "com.myapp.hasCompletedFirstLaunch"

    /// 在 App 生命周期最开始调用，SDK 初始化前。
    func performCleanupIfNeeded() async {
        let isSubsequentRun = UserDefaults.standard.bool(forKey: hasRunKey)
        guard !isSubsequentRun else { return }

        // iOS 15+ 预热保护：设备可能仍锁定
        guard await isProtectedDataAvailable() else {
            await waitForProtectedData()
            return
        }

        // 清除先前安装的陈旧 keychain 条目
        deleteAllKeychainItems()

        // 设置标志使此操作每次安装仅运行一次
        UserDefaults.standard.set(true, forKey: hasRunKey)
    }

    private func deleteAllKeychainItems() {
        let classes: [CFString] = [
            kSecClassGenericPassword, kSecClassInternetPassword,
            kSecClassCertificate, kSecClassKey, kSecClassIdentity
        ]
        for itemClass in classes {
            let query: NSDictionary = [
                kSecClass: itemClass,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny
            ]
            SecItemDelete(query)
        }
    }

    private func isProtectedDataAvailable() async -> Bool {
        await MainActor.run {
            UIApplication.shared.isProtectedDataAvailable
        }
    }

    private func waitForProtectedData() async {
        await withCheckedContinuation { continuation in
            NotificationCenter.default.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil, queue: .main
            ) { _ in
                Task {
                    self.deleteAllKeychainItems()
                    UserDefaults.standard.set(true, forKey: self.hasRunKey)
                    continuation.resume()
                }
            }
        }
    }
}
```

```swift
// ❌ 不正确：无首次启动清理——先前安装的陈旧 keychain
@main
struct BrokenApp: App {
    init() {
        // 不检查陈旧数据就读取 keychain
        if let token = try? keychainRead(service: "com.myapp", account: "authToken") {
            // 此令牌可能来自删除 App 的先前用户。
            // 新用户继承别人的会话。
            AuthManager.shared.restoreSession(token: token)
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

`isProtectedDataAvailable` 检查至关重要。iOS 15 引入 App 预热——系统可在用户解锁设备前启动你的进程。预热期间，UserDefaults 和带 `kSecAttrAccessibleWhenUnlocked` 的 keychain 条目都不可用。多个知名 App（包括 Twitter）在 iOS 15 上因启动代码将预热期间的空数据解释为"无凭据"并清除会话而遭受大规模用户登出。

> **在清理查询中包含 `kSecAttrSynchronizableAny`。** 没有它，`SecItemDelete` 跳过 iCloud 同步条目，留下它们作为不可见幽灵。

---

## 原子迁移：读 → 写 → 验证 → 删

最危险的模式是在确认 keychain 写入成功前删除遗留数据。正确序列始终是：**读 → 写 → 验证 → 删**。

```swift
// ✅ 正确：带验证和回滚的每键原子迁移
actor AtomicMigrator {
    struct MigrationResult {
        let key: String
        let succeeded: Bool
        let error: Error?
    }

    private let keychain: any MigrationKeychainProtocol

    init(keychain: any MigrationKeychainProtocol) {
        self.keychain = keychain
    }

    /// 失败的键保留在 UserDefaults 中以供下次启动重试。
    func migrateUserDefaultsKeys(
        _ keys: [String],
        service: String,
        accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) async -> [MigrationResult] {
        var results: [MigrationResult] = []

        for key in keys {
            do {
                // 步骤 1：从遗留存储读取
                guard let legacyValue = UserDefaults.standard.string(forKey: key),
                      let data = legacyValue.data(using: .utf8) else {
                    results.append(.init(key: key, succeeded: true, error: nil))
                    continue
                }

                // 步骤 2：写入 keychain（add-or-update 处理重复）
                try await keychain.save(data, service: service,
                                        account: key, accessible: accessible)

                // 步骤 3：通过回读验证
                let readBack = try await keychain.read(service: service, account: key)
                guard readBack == data else {
                    throw MigrationError.verificationFailed(key: key)
                }

                // 步骤 4：仅在验证写入后从 UserDefaults 删除
                UserDefaults.standard.removeObject(forKey: key)
                results.append(.init(key: key, succeeded: true, error: nil))

            } catch {
                // 回滚：为此键保留 UserDefaults 不变
                results.append(.init(key: key, succeeded: false, error: error))
            }
        }
        return results
    }

    enum MigrationError: Error {
        case verificationFailed(key: String)
        case corruptArchive(path: String)
    }
}
```

```swift
// ❌ 不正确：在验证 keychain 写入前删除遗留数据
func dangerousMigration() {
    let keys = ["authToken", "refreshToken"]
    for key in keys {
        guard let value = UserDefaults.standard.string(forKey: key) else { continue }

        // 先删除——如果 keychain 写入失败，数据永久丢失
        UserDefaults.standard.removeObject(forKey: key) // ← 灾难性

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.myapp",
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        // 如果 status != errSecSuccess，令牌永久丢失。
    }
}
```

迁移**设计上幂等**：已迁移的键在步骤 1 中从 UserDefaults 返回 `nil` 并被跳过。失败的键保留原始值，准备重试。这使其在崩溃、App 被杀或 OOM 终止后安全重新运行。

---

## 带 Schema 跟踪的版本化迁移

生产系统需要版本跟踪以避免重新运行已完成迁移并处理跳过版本的用户。schema 版本属于**keychain**（在重新安装后存活），而非 UserDefaults。

```swift
// ✅ 正确：带 keychain 中 schema 版本的版本化链迁移
actor MigrationCoordinator {
    static let shared = MigrationCoordinator()

    private let serviceName = "com.myapp.credentials"
    private let schemaVersionAccount = "com.myapp.schema.version"
    private static let currentSchemaVersion: Int = 3

    enum MigrationState {
        case upToDate
        case migrated(from: Int, to: Int)
        case deferred(reason: String)
        case failed(Error)
    }

    func migrateIfNeeded() async -> MigrationState {
        // 保护：受保护数据必须可用（预热防御）
        let dataAvailable = await MainActor.run {
            UIApplication.shared.isProtectedDataAvailable
        }
        guard dataAvailable else {
            return .deferred(reason: "Device locked — protected data unavailable")
        }

        let storedVersion = readSchemaVersion()
        guard storedVersion < Self.currentSchemaVersion else { return .upToDate }

        do {
            // 链迁移：每步顺序运行
            if storedVersion < 1 {
                try await migrateV0toV1_UserDefaultsToKeychain()
            }
            if storedVersion < 2 {
                try await migrateV1toV2_NSCodingArchivesToKeychain()
            }
            if storedVersion < 3 {
                try await migrateV2toV3_UpgradeAccessibilityClass()
            }

            // 仅在所有步骤成功后更新版本
            try saveSchemaVersion(Self.currentSchemaVersion)
            return .migrated(from: storedVersion, to: Self.currentSchemaVersion)
        } catch {
            // 不要更新 schema 版本——下次启动重试
            os_log(.error, log: .migration,
                   "Migration failed: %{public}@", error.localizedDescription)
            return .failed(error)
        }
    }

    // MARK: - Schema 版本（存储在 keychain 中，重新安装后存活）

    private func readSchemaVersion() -> Int {
        guard let data = try? keychainRead(
                  service: serviceName, account: schemaVersionAccount),
              let str = String(data: data, encoding: .utf8),
              let version = Int(str) else { return 0 }
        return version
    }

    private func saveSchemaVersion(_ version: Int) throws {
        let data = "\(version)".data(using: .utf8)!
        try keychainSave(data, service: serviceName,
                         account: schemaVersionAccount)
    }

    // MARK: - V1: UserDefaults → Keychain

    private func migrateV0toV1_UserDefaultsToKeychain() async throws {
        let migrator = AtomicMigrator(keychain: KeychainManager.shared)
        let results = await migrator.migrateUserDefaultsKeys(
            ["authToken", "refreshToken", "apiSecret"],
            service: serviceName
        )
        // 检查关键失败（未迁移的非 nil 键）
        let failures = results.filter { !$0.succeeded }
        if !failures.isEmpty {
            os_log(.error, log: .migration,
                   "V1 migration: %d keys failed", failures.count)
        }
        // 强制同步 UserDefaults 删除到磁盘
        UserDefaults.standard.synchronize()
    }

    // MARK: - V2: NSCoding 归档 → Keychain

    private func migrateV1toV2_NSCodingArchivesToKeychain() async throws {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        let archiveURL = documentsURL.appendingPathComponent("UserSession.archive")

        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return }

        let archiveData = try Data(contentsOf: archiveURL)
        guard let session = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: LegacySession.self, from: archiveData) else {
            throw AtomicMigrator.MigrationError.corruptArchive(path: archiveURL.path)
        }

        let sessionData = try JSONEncoder().encode(session.toModernSession())
        try keychainSave(sessionData, service: serviceName, account: "userSession")

        // 删除归档文件前验证
        let verified = try keychainRead(service: serviceName, account: "userSession")
        guard verified == sessionData else {
            throw AtomicMigrator.MigrationError.verificationFailed(key: "userSession")
        }
        try FileManager.default.removeItem(at: archiveURL)
    }

    // MARK: - V3: 升级现有条目的可访问性类别

    private func migrateV2toV3_UpgradeAccessibilityClass() async throws {
        let accounts = ["authToken", "refreshToken", "apiSecret", "userSession"]
        for account in accounts {
            guard let data = try? keychainRead(
                      service: serviceName, account: account) else { continue }
            // 用更新可访问性重新保存——add-or-update 模式
            // 通过 SecItemUpdate 更新可访问性类别
            try keychainSave(data, service: serviceName, account: account,
                             accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
    }
}

private extension OSLog {
    static let migration = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.myapp",
        category: "KeychainMigration"
    )
}
```

```swift
// ❌ 不正确：每次启动运行，无版本检查，无验证，无遗留删除
func brokenMigration() {
    // 无版本检查——每次启动运行
    // 无 isProtectedDataAvailable 检查——预热期间失败
    if let token = UserDefaults.standard.string(forKey: "authToken") {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.myapp",
            kSecAttrAccount as String: "authToken",
            kSecValueData as String: token.data(using: .utf8)!
        ]
        // 无 errSecDuplicateItem 处理——第二次启动崩溃
        SecItemAdd(query as CFDictionary, nil)
        // 永不从 UserDefaults 删除——明文密钥持久
        // 无写入成功验证
    }
}
```

链迁移方法（v1 → v2 → v3 顺序）故意选择而非直接迁移，因为它重用每个版本的已测试迁移逻辑。对于从 v1.0 直接升级到 v3.0 的用户，所有三步运行。schema 版本仅在所有步骤成功后推进——迁移中途崩溃使版本停留在旧编号以便干净重试。

---

## 孤立条目：为什么永不能重命名 kSecAttrService

```swift
// ❌ 不正确：SecItemUpdate 无法更改主键属性
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "OldServiceName",
    kSecAttrAccount as String: "authToken"
]
let update: [String: Any] = [
    kSecAttrService as String: "com.mycompany.myapp" // 错误：主键
]
// SecItemUpdate 返回错误——主键通过 Update 不可变
SecItemUpdate(query as CFDictionary, update as CFDictionary)
```

```swift
// ✅ 正确：必须更改服务名时的完整 rekey 迁移
func migrateServiceName() async throws {
    let oldService = "OldServiceName"
    let newService = "com.mycompany.myapp"
    let accounts = ["authToken", "refreshToken"]

    for account in accounts {
        let oldData: Data
        do {
            oldData = try keychainRead(service: oldService, account: account)
        } catch { continue } // 已迁移或从未存在

        try keychainSave(oldData, service: newService, account: account)

        // 删除旧之前验证新位置
        let verified = try keychainRead(service: newService, account: account)
        guard verified == oldData else {
            throw AtomicMigrator.MigrationError.verificationFailed(key: account)
        }
        try keychainDelete(service: oldService, account: account)
    }
}
```

**尽早锁定你的 `kSecAttrService` 值并永不更改。** 使用你的 bundle 标识符（如 `com.mycompany.myapp`）——它唯一、稳定且常规。

---

## 后台启动和锁定设备陷阱

iOS 15+ 预热和后台执行（推送通知、后台获取、Live Activities）可在设备锁定时启动你的 App。你选择的 `kSecAttrAccessible` 值决定这些上下文中 keychain 操作是否成功。

> 完整可访问性常量选择矩阵带数据保护层级和安全权衡，见 `keychain-access-control.md` § "何时"层：七个可访问性常量。下表总结了与后台迁移场景最相关的四个常量。

| 可访问性常量                             | 锁定时可访问 | 后台安全 | 备注                                                |
| --------------------------------------- | ------------ | -------- | --------------------------------------------------- |
| `kSecAttrAccessibleWhenUnlocked`（默认）| 否           | 否       | 仅前台                                              |
| `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | 首次解锁后 | 是       | **推荐**——后台 + 设备绑定                           |
| `kSecAttrAccessibleAfterFirstUnlock`    | 首次解锁后   | 是       | 后台 + 备份迁移（仅需要时使用）                     |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | 否     | 否       | 生物识别门控条目                                    |
| `kSecAttrAccessibleAlways`              | 是           | 是       | **iOS 12 废弃**——不要使用                           |

**迁移凭据的推荐默认：** `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`——后台安全，不同步到 iCloud，不包含在备份中。Apple 对 Wi-Fi 密码和邮件账户凭据使用 `AfterFirstUnlock`。

关键陷阱：**`SecItemDelete` 不需要条目的保护类别密钥材料**——即使条目数据因锁定状态不可读它也成功。这启用了灾难性反模式：

```swift
// ❌ 危险：读取失败时删除在后台启动期间销毁数据
func dangerousTokenRefresh() {
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    if status != errSecSuccess {
        // "不能读？一定损坏了。删除并重新开始。"
        SecItemDelete(query as CFDictionary) // ← 销毁有效令牌
        // 后台启动带 WhenUnlocked 时，读取失败
        // 带 -25308（交互不允许），但删除成功。
    }
}

// ✅ 正确：区分"未找到"和"设备锁定"
func safeTokenRead() throws -> Data? {
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
        return result as? Data
    case errSecItemNotFound:
        return nil // 真正缺失
    case errSecInteractionNotAllowed:
        // 设备锁定——条目存在但现在不可读。
        // 不要删除。不要视为缺失。稍后重试。
        throw KeychainError.interactionNotAllowed
    default:
        throw KeychainError.unexpectedStatus(status)
    }
}
```

**迁移规则：** 始终在 `UIApplication.shared.isProtectedDataAvailable` 后保护迁移。如果设备锁定，用 `protectedDataDidBecomeAvailableNotification` 推迟。永不要将锁定状态期间的空读取解释为"无内容迁移"。

---

## 幻影不匹配 Bug

在搜索查询中包含 `kSecAttrAccessible` 导致"未找到然后重复"悖论。搜索按可访问性类别过滤，但条目以不同类别存储——因此 `SecItemCopyMatching` 返回 `errSecItemNotFound`，而 `SecItemAdd` 通过主键看到条目并返回 `errSecDuplicateItem`。

```swift
// ❌ 不正确：搜索查询中的 kSecAttrAccessible 导致幻影不匹配
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked, // ← BUG
    kSecReturnData as String: kCFBooleanTrue as Any
]
// 如果用 AfterFirstUnlock 存储，查询返回 errSecItemNotFound。
// 但 SecItemAdd 通过主键看到条目 → errSecDuplicateItem。死锁。
```

**规则：** 搜索查询中仅使用**主键属性**（`kSecClass`、`kSecAttrService`、`kSecAttrAccount`）。仅在 `SecItemAdd` 期间或在 `SecItemUpdate` 的更新字典中设置 `kSecAttrAccessible`。

```swift
// ✅ 正确：仅按主键搜索
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecReturnData as String: kCFBooleanTrue as Any
]
```

---

## Team ID 变更：App 转移边缘情况

当 App 转移到不同 Apple Developer 账户时，Team ID 变化。Keychain 访问永久绑定到原始 Team ID——所有现有 keychain 条目在新签名身份下变得不可访问。用户实际上被登出并在更新后首次启动时丢失所有本地存储的密钥。

**如果 Team ID 变更不可避免**，你必须在转移前在**旧** Team ID 下发布"桥接"更新：

1. 桥接更新读取所有 keychain 条目并导出到临时的、应用组共享的容器（或 App 沙箱中的加密文件）
2. 转移 App 到新开发者账户
3. 新 Team ID 下的首个发布从临时存储读取，写入新 keychain，验证，删除临时数据

这是单向操作，必须提前充分计划。没有桥接更新，Team ID 变更后无法恢复 keychain 条目。

---

## 带回滚窗口的推迟遗留清理

最安全的方法是迁移后将遗留数据保留一个发布周期作为备份。在 keychain 中跟踪迁移时间戳：

```swift
// ✅ 正确：带 30 天回滚窗口的推迟清理
actor DeferredCleanup {
    private let cleanupDelayDays = 30
    private let timestampAccount = "com.myapp.migration.timestamp"
    private let serviceName = "com.myapp.credentials"

    func cleanupIfExpired() async {
        guard let data = try? keychainRead(
                  service: serviceName, account: timestampAccount),
              let str = String(data: data, encoding: .utf8),
              let migrationDate = ISO8601DateFormatter().date(from: str) else { return }

        let days = Calendar.current.dateComponents(
            [.day], from: migrationDate, to: Date()).day ?? 0
        guard days >= cleanupDelayDays else { return }

        // 超过回滚窗口——安全永久删除遗留文件
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first!
        for file in ["UserSession.archive", "Credentials.plist", "TokenCache.dat"] {
            try? FileManager.default.removeItem(
                at: documentsURL.appendingPathComponent(file))
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
```

---

## 完整 App 启动序列

App 启动时的正确排序至关重要。Keychain 清理必须在 SDK 初始化前发生，迁移必须等待受保护数据，schema 版本门控所有逻辑。

```swift
// ✅ 正确：带迁移的完整启动序列
@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { WindowGroup { ContentView() } }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Task {
            // 1. 首次启动清理（先前安装的陈旧 keychain）
            await FirstLaunchGuard.shared.performCleanupIfNeeded()

            // 2. 版本化迁移
            let state = await MigrationCoordinator.shared.migrateIfNeeded()
            switch state {
            case .upToDate: break
            case .migrated(let from, let to):
                os_log(.info, "Migrated schema v%d → v%d", from, to)
            case .deferred(let reason):
                os_log(.info, "Migration deferred: %{public}@", reason)
            case .failed(let error):
                os_log(.error, "Migration failed: %{public}@",
                       error.localizedDescription)
            }

            // 3. 超过回滚窗口的遗留文件推迟清理
            await DeferredCleanup().cleanupIfExpired()

            // 4. 现在初始化 Firebase、分析、认证 SDK
            // 陈旧数据已清除，迁移完成或安全推迟
        }
        return true
    }
}
```

---

## 线程安全说明

> **交叉验证说明：** 一个研究来源声称 SecItem C-API 非线程安全并推荐串行 `DispatchQueue`。Apple 文档和 Quinn "The Eskimo"（DTS）确认 **SecItem\* 函数在 iOS 上线程安全**。然而，你的包装器的可变状态（缓存、迁移标志、版本跟踪）确实需要同步。在现代 Swift 并发中 `actor` 自然提供此功能——新代码（iOS 15+）优先使用 actor 而非串行队列。

---

## 测试迁移路径

keychain 行为在 Simulator 和真实设备间不同：

| 方面                        | Simulator                | 真实设备                            |
| --------------------------- | ------------------------ | ----------------------------------- |
| 数据保护强制执行            | 不强制                   | 完全强制（硬件）                    |
| Keychain 权限               | 宽松强制                 | 严格强制                            |
| `errSecInteractionNotAllowed` | 很少触发                 | 锁定时触发                          |
| 锁定状态测试                | 无法有意义测试           | 可访问性验证必需                    |

单元测试使用**基于协议的抽象**（在 Simulator 上的 CI 中运行），真实设备集成测试用于可访问性类别验证：

```swift
// ✅ 用于可测试迁移的基于协议的 keychain 抽象
protocol MigrationKeychainProtocol: Actor {
    func save(_ data: Data, service: String, account: String,
              accessible: CFString) throws
    func read(service: String, account: String) throws -> Data
    func delete(service: String, account: String) throws
    func deleteAll()
}

// 单元测试的内存 mock
actor MockMigrationKeychain: MigrationKeychainProtocol {
    var store: [String: [String: Data]] = [:]
    var simulatedError: KeychainError?

    func save(_ data: Data, service: String, account: String,
              accessible: CFString) throws {
        if let error = simulatedError { throw error }
        store[service, default: [:]][account] = data
    }

    func read(service: String, account: String) throws -> Data {
        if let error = simulatedError { throw error }
        guard let data = store[service]?[account] else {
            throw KeychainError.itemNotFound
        }
        return data
    }

    func delete(service: String, account: String) throws {
        store[service]?[account] = nil
    }

    func deleteAll() { store.removeAll() }
}
```

```swift
// ✅ 示例：验证原子行为——keychain 失败时保留遗留数据
@Test func migrationPreservesLegacyDataOnKeychainFailure() async {
    let mock = MockMigrationKeychain()
    mock.simulatedError = .unexpectedStatus(-25308) // 模拟锁定设备

    let defaults = UserDefaults(suiteName: "test")!
    defaults.set("secret-token", forKey: "authToken")

    let migrator = AtomicMigrator(keychain: mock)
    let results = await migrator.migrateUserDefaultsKeys(
        ["authToken"], service: "com.myapp"
    )

    #expect(results.contains(where: { !$0.succeeded }))
    #expect(defaults.string(forKey: "authToken") == "secret-token") // 仍完整
}
```

始终在 `setUp()`/`tearDown()` 中清理 keychain 条目——条目在同一模拟器上的测试运行间持久。对于命中真实 keychain 的集成测试，创建带启用 Keychain 能力的 Test Host App 目标。

---

## 处理非常旧的版本和坍缩策略

App Store 始终交付最新二进制——从 v1.0 跳到 v3.0 的用户永不安装 v2.0。你的 v3.0 二进制必须包含每个历史 schema 版本的迁移逻辑。

务实地说，足够时间后（当分析显示 <1% 用户在遗留版本上），**将旧迁移坍缩为单个从 v0 到当前的 mega-migration**，减少代码维护。对于版本如此旧以至于遗留格式未知或损坏的用户，迁移应**优雅失败**并提示重新登录而非崩溃。

---

## 安全删除：信任加密擦除

**不要**尝试在删除前用零或随机字节手动覆盖文件——NAND 闪存磨损均衡使此无效且浪费写周期。iOS 通过加密擦除处理安全删除：每个文件有每文件 AES-256 密钥，当文件通过标准 API（`FileManager.removeItem`、`UserDefaults.removeObject`）删除时，iOS 通过 Effaceable Storage 销毁每文件密钥，使物理位永久不可恢复。

标准删除 API 足够。剩余风险是迁移_前_创建的未加密备份——鼓励用户使用加密备份，并在验证迁移后及时删除遗留数据。

---

## 结论

安全 keychain 迁移的核心洞察：**删除是不可逆步骤，而非写入**。本文件中的每个模式都遵循此原则——删除前验证，不确定时推迟，将 keychain 跨重装的持久性视为需要规划的特性而非要对抗的 bug。五个最有影响的决策是：使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 进行后台安全加密存储，在 SDK 初始化前实现首次启动清理，将 schema 版本存储在 keychain 而非 UserDefaults，在 `isProtectedDataAvailable` 后门控所有迁移，以及发布后永不更改 `kSecAttrService`。

---

## 总结清单

1. **首次启动清理在任何 SDK 初始化前运行** —— 使用 UserDefaults 标志检测重装，清除陈旧 keychain 条目，包含 `kSecAttrSynchronizableAny` 以捕获 iCloud 同步条目
2. **迁移是原子的：读 → 写 → 验证 → 删** —— 遗留数据在 keychain 写入通过回读确认前永不删除；失败的键保留完整以供重试
3. **Schema 版本存储在 keychain 中，而非 UserDefaults** —— 在 App 重新安装后存活；版本仅在所有迁移步骤成功后推进
4. **任何迁移前检查受保护数据可用性** —— 防御 iOS 15+ 预热和锁定设备场景；通过 `protectedDataDidBecomeAvailableNotification` 推迟
5. **`errSecInteractionNotAllowed` (-25308) 永不视为"条目缺失"** —— 区分锁定设备失败和真正缺失；读取失败时不检查状态码绝不删除
6. **`kSecAttrService` 和 `kSecAttrAccount` 发布后不可变** —— 更改任一孤立现有条目；`SecItemUpdate` 无法修改主键；如果必须更改使用完整 rekey 迁移
7. **`kSecAttrAccessible` 永不包含在搜索查询中** —— 导致幻影"未找到然后重复"不匹配；仅在添加或更新字典中设置
8. **默认可访问性是 `AfterFirstUnlockThisDeviceOnly`** —— 后台安全，不同步，不备份；匹配 Apple 自己的凭据存储模式
9. **带回滚窗口的推迟遗留清理** —— 迁移后保留遗留数据 30 天作为安全网；时间戳存储在 keychain 中
10. **Team ID 变更切断所有 keychain 访问** —— App 转移前必须在旧 Team ID 下发布桥接更新；无桥接转移后无法恢复
11. **通过基于协议的抽象测试迁移** —— 单元测试中 mock keychain；可访问性类别验证用真实设备集成测试；在 setUp/tearDown 中清理条目
