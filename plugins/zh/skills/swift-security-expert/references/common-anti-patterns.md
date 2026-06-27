# 常见反模式

> **范围：** AI 编码助手为 iOS App 生成的 10 个最危险的安全反模式。每个条目包括漏洞解释、真实的 ❌ 不安全代码、✅ 正确替代、检测启发式和 OWASP 风险映射。这是本技能的主干——纠正 AI 生成的安全代码最重要的文件。
>
> **交叉引用：** `biometric-authentication.md`（反模式 #3 深入）、`keychain-fundamentals.md`（反模式 #4 CRUD 模式）、`keychain-access-control.md`（反模式 #5 保护类别）、`cryptokit-symmetric.md`（反模式 #6–7）、`credential-storage-patterns.md`（反模式 #1–2 令牌生命周期）、`migration-legacy-stores.md`（反模式 #9 首次启动清理）、`compliance-owasp-mapping.md`（完整 OWASP/MASVS 映射）。

---

## 为什么 AI 生成不安全的 iOS 代码

AI 助手优化功能正确性而非安全性——复制训练数据中最常见的模式，这些模式压倒性地是默认不安全的。Veracode 2025 年分析：45% 的 AI 生成代码未通过安全测试。Cybernews：156,000 个 iOS App 中有 815,000+ 硬编码密钥（71% 泄露 ≥1 个凭据）。Stanford：使用 AI 的开发者编写更不安全的代码却感觉更自信。

Apple 的安全原语（Keychain、CryptoKit、Secure Enclave）优秀但 AI 一致地绕过它们。CISA/FBI 在 2025 年 1 月的 Bad Practices v2.0 中将硬编码凭据归类为提升"国家安全风险"（CWE-798）。

**OWASP 标准：** Mobile Top 10 (2024) 带 MASTG v2 测试 ID。旧版 MSTG-\* 标识符在常用引用处注明。

---

## 反模式 #1 — 在 UserDefaults 中存储密钥

**严重程度：** CRITICAL | **OWASP：** M9（不安全数据存储）| **修复工作量：** 中

UserDefaults 写入未加密的 XML plist 到 `~/Library/Preferences/{BUNDLE_ID}.plist`。Apple 文档："不要将个人或敏感信息作为设置存储。"可从未加密备份、越狱设备（Objection `ios nsuserdefaults get`）和第三方 SDK 读取。**SwiftUI 的 `@AppStorage` 是 `UserDefaults` 的包装器**——它具有相同的安全属性，永不能用于令牌、密钥或凭据。

**❌ 不安全——AI 生成模式：**

```swift
// 磁盘上明文，可从备份读取
func saveAuthToken(_ token: String) {
    UserDefaults.standard.set(token, forKey: "userAuthToken")
    UserDefaults.standard.set(refreshToken, forKey: "refreshToken")
    UserDefaults.standard.synchronize()
}

let token = UserDefaults.standard.string(forKey: "userAuthToken")
```

**✅ 安全——带 add-or-update 的 Keychain：**

```swift
func saveTokenToKeychain(_ token: Data, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.auth",
        kSecAttrAccount as String: account,
        kSecValueData as String: token,
        kSecAttrAccessible as String:
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecDuplicateItem {
        // 完整 add-or-update 模式 → 见反模式 #4
        let search: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.myapp.auth",
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(
            search as CFDictionary,
            [kSecValueData as String: token] as CFDictionary)
        guard updateStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    } else if status != errSecSuccess {
        throw KeychainError.unexpectedStatus(status)
    }
}
```

**MASTG 测试：** MASTG-TEST-0300、MASTG-TEST-0302。**MASWE：** MASWE-0006。**旧版：** MSTG-STORAGE-1。

**检测启发式：**

```bash
grep -rn "UserDefaults" --include="*.swift" | \
  grep -iE "token|password|secret|credential|auth|session|api.?key|jwt|bearer"
```

---

## 反模式 #2 — 硬编码 API 密钥

**严重程度：** CRITICAL | **OWASP：** M1（不当凭据使用）| **修复工作量：** 高

编译到 Swift 中的 API 密钥出现在二进制的 `__TEXT.__cstring` 段——`strings MyApp.app/MyApp` 立即提取它们。即使是 `.xcconfig` 或 `Info.plist` 值也打包在 IPA 内。Cybernews 在 156,000 个 iOS App 中发现 78,800 个 Google API 密钥。

**❌ 不安全——AI 生成模式：**

```swift
class PaymentService {
    private let stripeKey = "sk_live_51H7bK2E..."   // 在二进制中
    private let firebaseKey = "AIzaSyB..."            // 在二进制中

    func charge(amount: Int) async throws {
        var request = URLRequest(
            url: URL(string: "https://api.stripe.com/v1/charges")!)
        request.setValue("Bearer \(stripeKey)",
                        forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: request)
    }
}

// 同样危险：Info.plist 或 .xcconfig 中的密钥打包在 App 中
let key = Bundle.main.infoDictionary?["API_KEY"] as? String
```

**✅ 安全——服务器代理 + Keychain 缓存：**

```swift
class SecureAPIKeyManager {
    static let shared = SecureAPIKeyManager()

    /// 最佳：通过你的服务器代理（密钥永不在设备上）
    func secureRequest(endpoint: String, params: [String: Any]) async throws -> Data {
        var request = URLRequest(
            url: URL(string: "https://api.myserver.com/proxy/\(endpoint)")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    /// 如果客户端必须持有密钥：运行时获取，缓存在 Keychain
    func getAPIKey() async throws -> String {
        if let cached = try? readFromKeychain(service: "api-keys", account: "primary") {
            return String(data: cached, encoding: .utf8)!
        }
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "https://api.myserver.com/config/key")!)
        try saveToKeychain(data, service: "api-keys", account: "primary")
        return String(data: data, encoding: .utf8)!
    }
}
```

Apple 的 DeviceCheck 和 App Attest 框架提供服务端设备验证而无需嵌入密钥。WWDC 2019-709 建议将凭据存储在 Keychain 中，而非代码中。

**MASTG 测试：** MASTG-TEST-0213、MASTG-TEST-0214。**MASWE：** MASWE-0005。**旧版：** MSTG-STORAGE-12。**CISA/FBI：** CWE-798——Product Security Bad Practices v2.0（2025 年 1 月）。

**检测启发式：**

```bash
grep -rn 'let.*[Kk]ey.*=.*"[A-Za-z0-9_\-]\{20,\}"' --include="*.swift"
grep -rn '"sk_live_\|"pk_live_\|"AIza[A-Za-z0-9]\|"AKIA[A-Z0-9]' \
  --include="*.swift" --include="*.plist" --include="*.xcconfig"
```

---

## 反模式 #3 — 仅 LAContext 生物识别认证

**严重程度：** CRITICAL | **OWASP：** M3（不安全认证）| **修复工作量：** 中

单独使用 `LAContext.evaluatePolicy()` 是 iOS 教程中最被复制的危险模式。该方法返回用户空间中的简单布尔回调——无加密绑定。Frida 一条命令强制 `success = true`；Objection 将此打包为 `ios ui biometrics_bypass`。OWASP MASTG："生物识别认证必须基于解锁 keychain。" 完整深入：见 `biometric-authentication.md`。

**❌ 不安全——AI 生成模式：**

```swift
func authenticateUser(completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Authenticate to access your account"
    ) { success, authError in
        DispatchQueue.main.async {
            if success {
                self.showSensitiveData()  // 门控在可 hook 的布尔上
            }
            completion(success)
        }
    }
}
```

**✅ 安全——Keychain + SecAccessControl 硬件绑定：**

```swift
// 存储：通过 Secure Enclave 进行生物识别保护
func storeWithBiometric(secret: Data, account: String) throws {
    let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet, nil)!

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.biometric",
        kSecAttrAccount as String: account,
        kSecAttrAccessControl as String: access,
        kSecValueData as String: secret
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess || status == errSecDuplicateItem else {
        throw KeychainError.unexpectedStatus(status)
    }
}

// 读取：Secure Enclave 在释放数据前强制生物识别
func readWithBiometric(account: String) throws -> Data {
    let context = LAContext()
    context.localizedReason = "Access your secure data"
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.biometric",
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseAuthenticationContext as String: context
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        throw KeychainError.unexpectedStatus(status)
    }
    return data  // 仅在硬件生物识别验证后返回
}
```

`.biometryCurrentSet` 标志在生物识别变更时使条目失效，防止有物理访问权限的攻击者注册自己的生物识别。Objection 文档确认此绕过对 keychain 绑定的生物识别条目"无效"。

**MASTG 测试：** MASTG-TEST-0266、MASTG-TEST-0267。**MASWE：** MASWE-0044。**旧版：** MSTG-AUTH-8。**WWDC：** 2014-711 引入了 `SecAccessControlCreateWithFlags`。

**检测启发式：**

```bash
# evaluatePolicy 无 SecAccessControl → 不安全
grep -rn "evaluatePolicy" --include="*.swift" -l | \
  xargs grep -L "SecAccessControlCreateWithFlags"
# 验证安全模式存在
grep -rn "\.biometryCurrentSet\|\.biometryAny" --include="*.swift"
```

---

## 反模式 #4 — 忽略 SecItem 错误码

**严重程度：** HIGH | **OWASP：** M8（安全配置错误）| **修复工作量：** 低

`errSecDuplicateItem` (OSStatus -25299) 是最常见的 Keychain 失败。当 `SecItemAdd` 遇到重复时，它静默丢弃新值。密码更新永不持久化，刷新令牌丢失，认证以难以调试的方式中断。其他关键码：`errSecItemNotFound` (-25300)、`errSecAuthFailed` (-25293)、`errSecInteractionNotAllowed` (-25308)。

完整 CRUD 模式：见 `keychain-fundamentals.md`。

**❌ 不安全——AI 生成模式：**

```swift
func saveToken(_ token: Data) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.app.auth",
        kSecAttrAccount as String: "accessToken",
        kSecValueData as String: token
    ]
    SecItemAdd(query as CFDictionary, nil)  // 返回值被忽略！
}
```

**✅ 安全——带 add-or-update 的 OSStatus switch：**

```swift
func saveToKeychain(value: Data, service: String, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: value,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    switch status {
    case errSecSuccess: return
    case errSecDuplicateItem:
        let search: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(
            search as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        guard updateStatus == errSecSuccess else { throw KeychainError.updateFailed(updateStatus) }
    case errSecInteractionNotAllowed: throw KeychainError.deviceLocked
    case errSecAuthFailed: throw KeychainError.authenticationFailed
    default: throw KeychainError.unexpectedStatus(status)
    }
}
```

关键细节：`SecItemUpdate` 接受两个字典——搜索查询（不带 `kSecValueData`）和要更新的属性。将完整查询作为搜索参数传递是常见错误。

**MASTG 测试：** MASTG-TEST-0300、MASTG-TEST-0301。**旧版：** MASVS-STORAGE-2。

**检测启发式：**

```bash
grep -rn "SecItemAdd" --include="*.swift" -l | \
  xargs grep -L "errSecDuplicateItem\|DuplicateItem\|-25299"
grep -rn "SecItemAdd(" --include="*.swift" | \
  grep -v "let\|var\|status\|=\|switch\|if\|guard"
```

---

## 反模式 #5 — 错误或缺失的数据保护类别

**严重程度：** HIGH | **OWASP：** M9（不安全数据存储）| **修复工作量：** 低

省略 `kSecAttrAccessible` 继承可能不足的默认值。使用废弃的 `kSecAttrAccessibleAlways`（iOS 12 废弃）使数据在设备锁定时可解密。缺少 `ThisDeviceOnly` 后缀意味着条目包含在备份中。完整保护类别指南：见 `keychain-access-control.md`。

**❌ 不安全——AI 生成模式：**

```swift
// 完全省略 kSecAttrAccessible
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "user_password",
    kSecValueData as String: passwordData
]
SecItemAdd(query as CFDictionary, nil)

// 废弃——设备锁定时可访问
kSecAttrAccessible as String: kSecAttrAccessibleAlways
```

**✅ 安全——按用例选择：**

```swift
// 密码、认证令牌（仅前台）
kSecAttrAccessible as String:
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly

// 最高敏感度——需要密码存在
kSecAttrAccessible as String:
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly

// 后台访问条目（推送令牌、刷新令牌）
kSecAttrAccessible as String:
    kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

WWDC 2014-711："始终使用对你的 App 有意义的最严格选项。"

**MASTG 测试：** MASTG-TEST-0299。**旧版：** MASTG-STORAGE-3。

**检测启发式：**

```bash
grep -rn "kSecAttrAccessibleAlways\b" --include="*.swift"
grep -rn "SecItemAdd" --include="*.swift" -l | \
  xargs grep -L "kSecAttrAccessible\|kSecAttrAccessControl"
grep -rn "kSecAttrAccessibleWhenUnlocked\b" --include="*.swift" | \
  grep -v "ThisDeviceOnly"
```

---

## 反模式 #6 — AES-GCM 中的 Nonce 重用

**严重程度：** CRITICAL | **OWASP：** M10（加密不足）| **修复工作量：** 中

在 AES-GCM 中用相同密钥重用 nonce 是完全的加密破解。相同 nonce 产生相同密钥流，通过 `C1 ⊕ C2 = P1 ⊕ P2` 实现明文恢复，通过多项式因式分解（"禁止攻击"，Joux 2006）实现认证密钥恢复。CryptoKit 的 `AES.GCM.seal` 有安全默认：省略 `nonce` 参数自动生成随机 12 字节 nonce。危险发生在 AI 显式构造 nonce 时。完整模式：见 `cryptokit-symmetric.md`。

**❌ 不安全——AI 生成模式：**

```swift
import CryptoKit

// 硬编码 nonce——每次加密相同密钥流
let fixedNonce = try! AES.GCM.Nonce(data: Data(repeating: 0x00, count: 12))

func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(
        plaintext, using: key, nonce: fixedNonce)  // 灾难性
    return sealedBox.combined!
}
// 同样危险：基于计数器的 nonce 在 App 重启时重置 → 碰撞
```

**✅ 安全——让 CryptoKit 处理 nonce：**

```swift
import CryptoKit

func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
    // 省略 nonce → CryptoKit 生成随机 12 字节 nonce
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    return sealedBox.combined!  // 包含：nonce ‖ 密文 ‖ 标签
}

func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: combined)
    return try AES.GCM.open(sealedBox, using: key)
}

let key = SymmetricKey(size: .bits256)  // 按 WWDC 2025 指导的 AES-256
```

WWDC 2019-709 引入 CryptoKit，设计哲学："易于使用，难以误用。"

**MASTG 测试：** MASTG-TEST-0317。**MASWE：** MASWE-0022。**旧版：** MASTG-CRYPTO-4。

**检测启发式：**

```bash
grep -rn "AES\.GCM\.Nonce(data:" --include="*.swift"
grep -rn "let.*nonce.*=.*AES\.GCM\.Nonce" --include="*.swift"
grep -rn "Data(repeating:.*count:\s*12)" --include="*.swift"
grep -rn "\.seal(.*nonce:" --include="*.swift"
```

---

## 反模式 #7 — 将 MD5/SHA-1 用于安全目的

**严重程度：** HIGH | **OWASP：** M10（加密不足）| **修复工作量：** 低

MD5 自 Wang & Yu (2005) 起被破解；SHA-1 被 SHAttered (2017) 破解。CISA 2025 年 1 月将两者列为不安全。Apple 通过 CryptoKit 的 `Insecure.MD5` 和 `Insecure.SHA1` 命名空间发出此信号。

**❌ 不安全——AI 生成模式：**

```swift
import CryptoKit
func hashPassword(_ password: String) -> String {
    let hash = Insecure.MD5.hash(data: password.data(using: .utf8)!)
    return hash.map { String(format: "%02x", $0) }.joined()
}
// 同样：来自 CommonCrypto 的 CC_MD5、CC_SHA1
```

**✅ 安全——最低 SHA-256，密码用 KDF：**

```swift
import CryptoKit

// 完整性验证
func hashData(_ data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}

// 消息认证的 HMAC
func authenticate(_ data: Data, key: SymmetricKey) -> Data {
    Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
}

// 密码存储——永不原始哈希。使用 KDF：
// 服务端：Argon2id、bcrypt 或 scrypt
// 设备上：PBKDF2 ≥600,000 次迭代（OWASP 2023 HMAC-SHA256 最低值）
// 见 cryptokit-symmetric.md 了解完整 PBKDF2 实现
```

iOS 18 在 CryptoKit 中添加 SHA-3 系列（`SHA3_256`、`SHA3_384`、`SHA3_512`）。WWDC 2025-314 涵盖后量子添加（ML-KEM、ML-DSA），而非 SHA-3。

**MASTG 测试：** MASTG-TEST-0211。**MASTG 演示：** MASTG-DEMO-0015、MASTG-DEMO-0016。**旧版：** MSTG-CRYPTO-1。

**检测启发式：**

```bash
grep -rn "Insecure\.\(MD5\|SHA1\)" --include="*.swift"
grep -rn "CC_MD5\|CC_SHA1\|CC_MD5_DIGEST_LENGTH\|CC_SHA1_DIGEST_LENGTH" \
  --include="*.swift" --include="*.m"
```

---

## 反模式 #8 — 记录敏感数据

**严重程度：** HIGH | **OWASP：** M9（不安全数据存储）| **修复工作量：** 低

`print()`、`NSLog()` 和 `os_log()` 带敏感值会持久到设备日志——可通过 Xcode Console、`idevicesyslog` 和 `log collect --device` 访问。在越狱设备上，任何进程都可读取日志存储。Apple 的 `OSLogPrivacy` (iOS 14+)：`.private` 在生产中脱敏；`.sensitive` (iOS 15+) 始终脱敏。

**❌ 不安全——AI 生成模式：**

```swift
func login(username: String, password: String) async throws {
    print("Logging in with password: \(password)")       // 在设备日志中！
    let token = try await authService.authenticate(username, password)
    print("Got auth token: \(token)")                     // 在设备日志中！
    os_log("API key loaded: %{public}@", apiKey)          // 显式公开！
}
```

**✅ 安全——带脱敏的 OSLogPrivacy：**

```swift
import os

let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "auth")

func login(username: String, password: String) async throws {
    // 记录事件，不记录值——.private(mask: .hash) 启用关联
    logger.info("Login attempt: \(username, privacy: .private(mask: .hash))")
    let token = try await authService.authenticate(username, password)
    logger.info("Authentication succeeded")  // 无令牌值
}

// 遗留 os_log
os_log("Account: %{private}@", log: .default, type: .info, accountNumber)

// 在发布构建中剥离调试日志
#if DEBUG
print("Debug: \(sensitiveValue)")
#endif
```

**MASTG 测试：** MASTG-TEST-0296、MASTG-TEST-0297。**MASWE：** MASWE-0001。**旧版：** MSTG-STORAGE-3。

**检测启发式：**

```bash
grep -rn "print(.*\\\(" --include="*.swift" | \
  grep -iE "password|token|secret|key|credential|ssn|credit"
grep -rn "NSLog(.*%@" --include="*.swift" --include="*.m" | \
  grep -iE "password|token|secret|key"
grep -rn 'os_log.*%{public}' --include="*.swift" | \
  grep -iE "password|token|secret|key"
```

---

## 反模式 #9 — 首次启动时不清理 Keychain

**严重程度：** MEDIUM | **OWASP：** M9（不安全数据存储）| **修复工作量：** 低

Keychain 条目持久存在于 `securityd` 管理的系统范围加密数据库中，位于 App 沙箱外。App 删除移除沙箱但 keychain 条目存活。Apple DTS 工程师 Quinn "The Eskimo!" 确认这是"当前预期行为，尽管是明显的隐私问题。" 后果：重新安装时陈旧凭据、设备转售时跨用户数据泄露、重新安装时 Firebase SDK 认证错误。完整迁移模式：见 `migration-legacy-stores.md`。

**❌ 缺失模式——AI 永不生成：**

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
    // 来自先前安装的陈旧 keychain 条目静默持久
}
```

**✅ 安全——首次启动 keychain 清理：**

```swift
@main
struct MyApp: App {
    init() { clearKeychainIfFirstLaunch() }

    var body: some Scene {
        WindowGroup { ContentView() }
    }

    private func clearKeychainIfFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "hasLaunchedBefore") else { return }

        // UserDefaults 在卸载时被清除 → 这是首次启动
        for secClass in [kSecClassGenericPassword, kSecClassInternetPassword,
                         kSecClassCertificate, kSecClassKey, kSecClassIdentity] {
            SecItemDelete([
                kSecClass: secClass,
                kSecAttrSynchronizable: kSecAttrSynchronizableAny
            ] as NSDictionary)
        }
        defaults.set(true, forKey: "hasLaunchedBefore")
    }
}
```

将此放在初始化任何从 Keychain 读取的 SDK（Firebase、分析）之前。包含 `kSecAttrSynchronizableAny` 确保 iCloud Keychain 条目也被清除。

**MASTG 测试：** MASTG-TEST-0300、MASTG-TEST-0301。**旧版：** MSTG-STORAGE-11。

**检测启发式：**

```bash
grep -rn "SecItemAdd\|SecItemCopyMatching" --include="*.swift" -l | \
  xargs grep -L "hasLaunchedBefore\|isFirstLaunch\|firstRun"
grep -rn "SecItemDelete" --include="*.swift" -l | \
  xargs grep "hasLaunchedBefore\|isFirstLaunch"
```

---

## 反模式 #10 — 安全操作使用非加密 RNG

**严重程度：** HIGH | **OWASP：** M10（加密不足）| **修复工作量：** 低

`arc4random()` 仅返回 32 位 `UInt32`——对需要 128–256 位的加密目的不足。逐字符令牌构造引入偏差。真正非加密替代（`rand()`、`drand48()`、GameplayKit RNG）永不能用于安全操作。

**❌ 不安全——AI 生成模式：**

```swift
func generateToken() -> String {
    return String(arc4random_uniform(999_999))  // ~20 位熵
}

func generateSessionId(length: Int = 16) -> String {
    let chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    return String((0..<length).map { _ in chars.randomElement()! })  // 偏差
}
// 同样危险：srand48/drand48、rand()、GameplayKit RNG
```

**✅ 安全——SecRandomCopyBytes / CryptoKit：**

```swift
import Security
import CryptoKit

// SecRandomCopyBytes——标准 iOS 加密 RNG
func generateSecureToken(byteCount: Int = 32) throws -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
        throw CryptoError.randomGenerationFailed(status)
    }
    return bytes.map { String(format: "%02x", $0) }.joined()
}

// CryptoKit 密钥生成（内部安全 RNG）
let encryptionKey = SymmetricKey(size: .bits256)
```

`SecRandomCopyBytes` 通过 corecrypto 的 `ccrng_generate` 从 Secure Enclave 的硬件 TRNG 获取熵。它通过返回状态报告错误——不像 `arc4random` 静默无法失败。

**MASTG 测试：** MASTG-TEST-0311。**MASTG 演示：** MASTG-DEMO-0073、MASTG-DEMO-0074。**旧版：** MSTG-CRYPTO-6。

**检测启发式：**

```bash
grep -rn "arc4random\|arc4random_uniform\|arc4random_buf" --include="*.swift" | \
  grep -iE "token|nonce|salt|key|secret|session|iv"
grep -rn "\bsrand\b\|\brand()\|\brandom()\|\bdrand48\b" --include="*.swift"
grep -rn "GKARC4RandomSource\|GKMersenneTwisterRandomSource" --include="*.swift"
```

---

## 快速参考矩阵

| #   | 反模式                  | OWASP 2024 | MASTG 测试      | 危险 API                | 安全 API                            | 修复工作量 |
| --- | ----------------------- | ---------- | --------------- | ----------------------- | ----------------------------------- | ---------- |
| 1   | UserDefaults 密钥       | M9         | MASTG-TEST-0302 | `UserDefaults.set`      | `SecItemAdd` + Keychain             | 中         |
| 2   | 硬编码 API 密钥         | M1         | MASTG-TEST-0213 | 字符串字面量            | 服务器代理 + Keychain 缓存          | 高         |
| 3   | 仅 LAContext 生物识别   | M3         | MASTG-TEST-0266 | `evaluatePolicy`        | `SecAccessControlCreateWithFlags`   | 中         |
| 4   | 忽略 SecItem 错误       | M8         | MASTG-TEST-0300 | 未检查的 `SecItemAdd`   | OSStatus switch + `SecItemUpdate`   | 低         |
| 5   | 错误数据保护            | M9         | MASTG-TEST-0299 | `kSecAttrAccessibleAlways` | `WhenUnlockedThisDeviceOnly`        | 低         |
| 6   | AES-GCM nonce 重用      | M10        | MASTG-TEST-0317 | `AES.GCM.Nonce(data:)`  | 省略 nonce（自动随机）              | 中         |
| 7   | MD5/SHA-1 用于安全      | M10        | MASTG-TEST-0211 | `Insecure.MD5/.SHA1`    | `SHA256`+ / 密码用 KDF              | 低         |
| 8   | 记录敏感数据            | M9         | MASTG-TEST-0297 | `print(token)`          | `Logger` + `.private`               | 低         |
| 9   | 无 keychain 清理        | M9         | MASTG-TEST-0300 | 缺少清理                | UserDefaults 标志 + `SecItemDelete` | 低         |
| 10  | 非加密 RNG              | M10        | MASTG-TEST-0311 | `arc4random()`          | `SecRandomCopyBytes`                | 低         |

---

## CI/CD 检测策略

**Semgrep**（pre-commit/PR 门）：快速结构化模式匹配，用于 `UserDefaults` 误用、缺少 `errSecDuplicateItem`、`LAContext` 布尔。有限数据流分析。

**CodeQL**（夜间/PR 门）：深度语义污点跟踪——捕获分配给变量然后被记录的令牌。执行较慢。

**二进制扫描**（构建后）：对编译二进制执行 `strings`/`class-dump`，捕获在源码级混淆中存活的硬编码密钥。

推荐：每个 PR 用 Semgrep + 构建后二进制扫描。夜间用 CodeQL 深度分析。

---

## iOS 26 / WWDC 2025 影响

WWDC 2025-314 引入了自 2019 年以来最重要的 CryptoKit 扩展：

- **对称密钥：** 推荐使用 `.bits256` 而非 `.bits128` 以抵抗量子（反模式 #6、#10）
- **哈希：** CryptoKit 中的 SHA-3 系列（`SHA3_256/384/512`）在 iOS 18+ 上（反模式 #7）
- **后量子：** ML-KEM 768/1024、ML-DSA 65/87、X-Wing——全部支持 Secure Enclave
- **TLS：** iOS 26 中 `URLSession` 默认启用 `X25519MLKEM768`
- **Secure Enclave：** 硬件后量子密钥创建强化了反模式 #3 和 #5 的修复

---

## 总结清单

审查 iOS 代码的安全反模式时，验证每项：

1. **UserDefaults 中无密钥** —— 令牌、密码、API 密钥、JWT 使用 Keychain 并带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 或更严格
1. **源码中无硬编码密钥** —— API 密钥运行时通过服务器代理或认证端点获取；无高熵字符串字面量，无 `.xcconfig` 或 `Info.plist` 中的密钥
1. **生物识别绑定到 Keychain** —— `evaluatePolicy` 永不单独用于门控敏感操作；`SecAccessControlCreateWithFlags` 与 `.biometryCurrentSet` 保护 keychain 条目
1. **所有 SecItem 调用都检查** —— `SecItemAdd` 用 `SecItemUpdate` 回退处理 `errSecDuplicateItem`；`SecItemCopyMatching` 处理 `errSecItemNotFound`；无丢弃的 `OSStatus` 返回值
1. **显式数据保护类别** —— 每个 `SecItemAdd` 包含 `kSecAttrAccessible` 或 `kSecAttrAccessControl`；无 `kSecAttrAccessibleAlways`；非同步条目使用 `ThisDeviceOnly` 变体
1. **无 nonce 重用** —— `AES.GCM.seal` 不带显式 `nonce:` 参数调用（自动随机）；无存储/全局/计数器 nonce 变量
1. **无破损哈希** —— 无 `Insecure.MD5`、`Insecure.SHA1`、`CC_MD5`、`CC_SHA1` 用于安全目的；密码使用 KDF（Argon2id、bcrypt、PBKDF2 ≥310,000 次迭代）
1. **日志中无敏感数据** —— `print()` 和 `NSLog()` 永不包含令牌、密钥或凭据；`os_log` 使用 `%{private}@`；`Logger` 使用 `.private` 或 `.private(mask: .hash)`
1. **首次启动 keychain 清理** —— `UserDefaults` 标志 + `SecItemDelete` 对所有类别在 App 启动时 SDK 初始化前运行
1. **仅加密 RNG** —— `SecRandomCopyBytes` 或 CryptoKit API 用于令牌、nonce、盐、密钥；安全上下文中无 `arc4random` / `rand()` / `drand48()` / GameplayKit RNG
1. **iOS 26 就绪** —— 对称密钥使用 `.bits256`；无废弃算法；了解后量子 CryptoKit API 用于前瞻性实现
