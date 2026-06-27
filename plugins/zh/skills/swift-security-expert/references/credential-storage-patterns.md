# 凭据存储模式

> 范围：Apple 平台上客户端凭据的安全生命周期模式，包括存储、刷新、轮换、迁移和登出清理。

iOS Keychain 是 Apple 认可的唯一 OAuth 令牌、API 密钥、密码和其他凭据的存储机制。Cybernews 2025 年发现 71% 的 iOS App 泄露至少一个硬编码密钥——主要通过 `UserDefaults`、`Info.plist` 或 `.xcconfig` 文件，这些产生可从设备备份或 IPA bundle 中轻松提取的明文制品。本参考涵盖完整凭据生命周期：通过 Keychain Services 的安全存储、OAuth2/OIDC 认证流程、带轮换的原子令牌刷新、运行时密钥获取、密钥轮换策略和全面登出清理。

权威来源：Apple Developer Documentation（Keychain Services、Authentication Services）、Apple Platform Security Guide（2024 年 12 月）、WWDC 2019 Session 516 "What's New in Authentication"、WWDC 2021 Session 10105 "Secure login with iCloud Keychain verification codes"、WWDC 2024 Session 10125 "Streamline sign-in with passkey upgrades and credential managers"、OWASP Mobile Top 10 2024、MASVS v2.1.0（2024 年 1 月）、MASTG v2、CISA/FBI "Product Security Bad Practices" 咨询 v2.0（2025 年 1 月）和 Cybernews iOS App 安全研究（2025 年 3 月）。

---

## AI 代码生成器复现的六个反模式

AI 编码助手例行生成不安全的凭据处理。下面每个反模式都有证据、不正确代码示例和正确替代。

### 反模式 1 — UserDefaults 中的令牌

`UserDefaults` 写入未加密的 XML plist 到 `/var/mobile/Containers/Data/Application/{APP_ID}/Library/Preferences/{BUNDLE_ID}.plist`。此文件包含在 iTunes/Finder 设备备份中，非越狱设备上可用 iMazing 或 iExplorer 读取，越狱设备上可通过 `objection` 的 `ios nsuserdefaults get` 命令轻松提取。Apple 文档明确：defaults 系统以未加密格式在磁盘上存储信息，不得用于个人或敏感信息。

```swift
// ❌ 不正确——AI 生成的 UserDefaults 令牌存储
// 令牌以明文 XML plist 写入，可从设备备份读取
func saveTokens(accessToken: String, refreshToken: String) {
    UserDefaults.standard.set(accessToken, forKey: "access_token")
    UserDefaults.standard.set(refreshToken, forKey: "refresh_token")
}
```

**OWASP 映射：** 违反 M9（不安全数据存储）、MASVS-STORAGE-1、MASWE-0002，未通过 MASTG-TEST-0300/0301。

> 完整的 ❌/✅ 代码示例、objection 检测命令和此模式的完整修复清单，见 `common-anti-patterns.md` § 反模式 #1 — 在 UserDefaults 中存储密钥。

### 反模式 2 — 源码中硬编码 API 密钥

CISA 和 FBI 将硬编码凭据归类为正式"坏安全实践"（CWE-798，2024 年 CWE Top 25 中排名）。Cybernews 研究团队通过解压 IPA 文件并扫描明文，在 156,080 个 iOS App 中发现 815,000+ 硬编码密钥——无需反编译。

```swift
// ❌ 不正确——通过 `strings` 在 Mach-O 二进制上可发现的硬编码 API 密钥
struct APIConfig {
    static let stripeSecretKey = "sk_live_51ABC123DEF456..."
    static let firebaseAPIKey = "AIzaSyB1234567890abcdefg"
}
// 攻击者运行：strings MyApp.app/MyApp | grep "sk_live"
```

**OWASP 映射：** 违反 M1（不当凭据使用）、MASWE-0005 和 CISA/FBI 咨询项 #8。

### 反模式 3 — .xcconfig 中的生产密钥

`.xcconfig` 模式仅解决 git 提交问题。当你在 Info.plist 中引用 `$(MY_API_KEY)` 时，Xcode 在构建时解析变量并将字面明文值嵌入编译后的 `.app` bundle 内的 Info.plist 中。提取只需几秒：重命名 `.ipa` 为 `.zip`，解压，打开 Info.plist。

```swift
// ❌ 不正确——.xcconfig 值以明文编译到 Info.plist 中
// 在 Secrets.xcconfig 中：MAPS_API_KEY = gm_pk_a1b2c3d4e5f6g7h8i9
// 在 Info.plist 中：<key>MapsAPIKey</key><string>$(MAPS_API_KEY)</string>

let apiKey = Bundle.main.infoDictionary?["MapsAPIKey"] as? String
// 攻击者：unzip App.ipa && plutil -p Payload/App.app/Info.plist | grep Maps
```

### 反模式 4 — 缺少 kSecAttrAccessible 规范

添加 Keychain 条目时不指定 `kSecAttrAccessible`，系统应用默认：`kSecAttrAccessibleWhenUnlocked` (iOS 4.0+)。虽然合理，但此默认允许 Keychain 条目通过加密备份迁移到新设备，并将无密码设备视为"始终解锁"。显式设置 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 防止备份迁移并将凭据限制在原始硬件。

### 反模式 5 — 非原子令牌刷新

当访问令牌过期时，App 必须删除旧令牌并存储新令牌。如果 App 在这些操作之间崩溃，Keychain 进入不一致状态。并发刷新尝试使问题复杂化：两个线程都可能检测到过期，都调用刷新端点，一个写入陈旧或已轮换的刷新令牌。使用 Refresh Token Rotation (RTR) 时，此竞争可能使整个令牌族失效。

### 反模式 6 — 登出时凭据清理不完整

最常见的部分清理 bug 是删除访问令牌但将刷新令牌留在 Keychain 中。刷新令牌通常寿命更长且更强大——它可以静默生成新访问令牌。

```swift
// ❌ 不正确——部分清理留下刷新令牌
func logout() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.myapp.auth",
        kSecAttrAccount as String: "access_token"
    ]
    SecItemDelete(query as CFDictionary)
    // BUG：refresh_token、user_profile、缓存的 API 密钥全部留下
}
```

### 凭据存储的正确基线

✅ 将凭据存储在 Keychain 中，而非 `UserDefaults`/plist/源码字面量。
✅ 根据访问模式为每个条目显式设置 `kSecAttrAccessible`。
✅ 使用 add-or-update 语义并处理所有 `OSStatus` 结果。
✅ 登出时删除所有凭据制品（访问令牌、刷新令牌、派生缓存）。

---

## 凭据的数据保护类别选择

选择正确的 `kSecAttrAccessible` 值是凭据保密性的最高 ROI 决策。Keychain 使用双 AES-256-GCM 密钥加密条目：元数据密钥（缓存用于快速搜索）和每行密钥密钥（始终需要 Secure Enclave 往返）（Apple Platform Security Guide，2024 年 12 月；完整架构：`keychain-fundamentals.md` § 双层加密和查询成本）。

| 可访问性类别                                        | 设备绑定 | 后台访问           | 主要用例              | 风险说明                                                           |
| --------------------------------------------------- | -------- | ------------------ | --------------------- | ------------------------------------------------------------------ |
| `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`      | 是       | 否                 | OAuth 令牌、API 密钥  | **推荐默认**——对凭据最强                                          |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`   | 是       | 否                 | 最高保证密钥          | 用户移除密码时条目永久销毁                                         |
| `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`  | 是       | 是（首次解锁后）   | 后台令牌刷新          | 暴露窗口更大；仅在需要后台访问时使用                               |
| `kSecAttrAccessibleAfterFirstUnlock`                | 否       | 是                 | 后台 + 备份迁移       | 通过加密备份传输；避免用于敏感令牌                                 |

**经验法则：** 所有 OAuth 令牌和 API 密钥默认使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。仅当需要后台刷新时（如静默推送通知处理）使用 `AfterFirstUnlockThisDeviceOnly`。永不对 App 令牌使用 `kSecAttrSynchronizable`——iCloud Keychain 同步是为网站密码设计的，而非应用密钥。

> 完整可访问性常量选择标准、数据保护层级说明和 `SecAccessControl` 交互规则，见 `keychain-access-control.md` § "何时"层：七个可访问性常量。

---

## 基于 Actor 的 KeychainManager — 线程安全的凭据存储

`SecItemAdd`、`SecItemCopyMatching`、`SecItemUpdate` 和 `SecItemDelete` 函数（均为 iOS 2.0+）是执行到 `securityd` 守护进程 IPC 的同步 C 函数。它们对独立条目是线程安全的，但对同一条目的并发修改会产生竞争条件—— notably 当两个线程同时尝试添加缺失条目时产生 `errSecDuplicateItem` (-25299)。Swift actor（iOS 13+，iOS 17+ 成熟并发推荐）提供串行执行器消除这些竞争。

```swift
// ✅ 正确——基于 Actor 的 KeychainManager 带正确 kSecAttrAccessible
// 要求：iOS 13+（actor），推荐 iOS 17+ 以成熟并发
import Foundation
import Security

public actor KeychainManager {

    public enum KeychainError: Error {
        case unexpectedStatus(OSStatus), itemNotFound, encodingFailed, decodingFailed
    }

    let service: String
    private let accessGroup: String?
    private let accessibility: CFString

    public init(service: String, accessGroup: String? = nil,
                accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) {
        self.service = service; self.accessGroup = accessGroup; self.accessibility = accessibility
    }

    func baseQuery(account: String) -> [CFString: Any] {
        var q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecAttrAccount: account, kSecAttrAccessible: accessibility
        ]
        if let accessGroup { q[kSecAttrAccessGroup] = accessGroup }
        #if os(macOS)
        q[kSecUseDataProtectionKeychain] = true   // macOS 上的 iOS 风格数据保护
        #endif
        return q
    }

    /// Add-or-update 语义：先尝试更新，回退到添加。
    public func save(account: String, data: Data) throws {
        var searchQ = baseQuery(account: account)
        searchQ.removeValue(forKey: kSecAttrAccessible)
        let attrs: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: accessibility]
        var status = SecItemUpdate(searchQ as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQ = baseQuery(account: account); addQ[kSecValueData] = data
            status = SecItemAdd(addQ as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    public func load(account: String) throws -> Data {
        var q = baseQuery(account: account)
        q.removeValue(forKey: kSecAttrAccessible)
        q[kSecReturnData] = kCFBooleanTrue; q[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        switch status {
        case errSecSuccess: guard let d = result as? Data else { throw KeychainError.decodingFailed }; return d
        case errSecItemNotFound: throw KeychainError.itemNotFound
        default: throw KeychainError.unexpectedStatus(status)
        }
    }

    public func delete(account: String) throws {
        var q = baseQuery(account: account); q.removeValue(forKey: kSecAttrAccessible)
        let s = SecItemDelete(q as CFDictionary)
        guard s == errSecSuccess || s == errSecItemNotFound else { throw KeychainError.unexpectedStatus(s) }
    }

    /// 删除此服务的所有条目——登出时使用。
    public func deleteAll() throws {
        var q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service as CFString]
        if let accessGroup { q[kSecAttrAccessGroup] = accessGroup as CFString }
        #if os(macOS)
        q[kSecUseDataProtectionKeychain] = true
        #endif
        let s = SecItemDelete(q as CFDictionary)
        guard s == errSecSuccess || s == errSecItemNotFound else { throw KeychainError.unexpectedStatus(s) }
    }
}
```

**为什么用 actor？** actor 的串行执行器保证 `save`、`load`、`delete` 和 `deleteAll` 永不交错。两个并发调用者对同一账户调用 `save` 会排队而非竞争。同步 `SecItem*` C 调用在 actor 内安全执行——调用者 `await` 访问，挂起而非阻塞协作线程池。

**全局 actor 替代**——当 Keychain 序列化必须跨多个模块时：

```swift
// ✅ 模式：跨模块 Keychain 序列化的全局 actor
// 要求：iOS 13.0+（通过 Swift 5.5+ 的全局 actor）
@globalActor
actor KeychainActor {
    static let shared = KeychainActor()
}

@KeychainActor
func saveCredential(_ data: Data, account: String) throws {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.myapp.auth" as CFString,
        kSecAttrAccount: account as CFString,
        kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecValueData: data
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
```

---

## OAuth2 令牌存储和检索周期

`ASWebAuthenticationSession` (iOS 12.0+) 是基于 Web 的安全登录流程的强制标准。使用 `WKWebView` 或 `SFSafariViewController` 等遗留 Web 视图进行 OAuth 是重大反模式——它们允许宿主 App 检查 Web 内容或窃取凭据。WWDC 2019 "What's New in Authentication" 正式建议从废弃的 `SFAuthenticationSession` 迁移到 `ASWebAuthenticationSession`。

### 令牌模型

```swift
// ✅ 正确——带过期跟踪的 Codable 令牌模型
struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let tokenType: String

    var isExpired: Bool {
        Date() >= expiresAt
    }

    /// 过期前主动刷新。
    /// 两个提供商都同意：在生命周期的 75–90% 或带固定
    /// 缓冲（如 60 秒）刷新，以考虑网络延迟和时钟偏差。
    var shouldRefresh: Bool {
        let buffer: TimeInterval = 60
        return Date() >= expiresAt.addingTimeInterval(-buffer)
    }
}
```

### ASWebAuthenticationSession + PKCE 流程

```swift
// ✅ 正确——ASWebAuthenticationSession + PKCE + Keychain 存储
// 要求：iOS 13.0+（用于 prefersEphemeralWebBrowserSession）
import AuthenticationServices
import CryptoKit

final class OAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {

    private let keychain = KeychainManager(
        service: "com.myapp.auth",
        accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )
    private let clientID = "mobile-app-client" // 公共客户端，无需密钥
    private let redirectScheme = "com.myapp.auth"

    func startAuthentication() async throws -> OAuthTokens {
        let codeVerifier = generateCodeVerifier()  // RFC 7636 PKCE
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://auth.example.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: "\(redirectScheme)://callback"),
            URLQueryItem(name: "scope", value: "openid profile offline_access"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!, callbackURLScheme: redirectScheme
            ) { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
            }
            session.prefersEphemeralWebBrowserSession = true  // iOS 13+：无 cookie 共享
            session.presentationContextProvider = self
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.missingAuthorizationCode
        }

        let tokens = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
        try await keychain.save(account: "oauth_tokens", data: JSONEncoder().encode(tokens))
        return tokens
    }

    // MARK: - PKCE 助手 (RFC 7636)

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        // CryptoKit SHA256 (iOS 13.0+)——替代遗留 CC_SHA256
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> OAuthTokens {
        // 标准 OAuth2 令牌交换——用你的授权服务器实现
        fatalError("Implement token exchange")
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { ASPresentationAnchor() }
    enum OAuthError: Error { case missingAuthorizationCode }
}
```

**iOS 17.4+ 改进：** `ASWebAuthenticationSession.Callback` 启用 HTTPS 通用链接回调而非自定义 URL 方案。通用链接提供域所有权的加密保证，使其显著不易被拦截（RFC 8252，OAuth 2.0 for Native Apps）。

**隐私 vs SSO 权衡：** 设置 `prefersEphemeralWebBrowserSession = true` 最大化隐私和会话隔离但破坏单点登录。根据你的 App 优先严格隔离还是无缝 SSO 切换。

---

## 带轮换支持的原子令牌刷新

当服务器实现 Refresh Token Rotation (RTR)——如 Okta、Auth0 等所做——每次刷新响应包含新刷新令牌，旧令牌立即失效。如果 App 存储新访问令牌但在持久化新刷新令牌前崩溃，用户被锁定。解决方案：在 actor 的串行执行上下文中原子更新两个令牌。

服务器通常提供短暂宽限期（如 Okta 配置的 30 秒），在此期间先前刷新令牌保持有效以处理网络重试。如果在宽限期内重用先前失效的令牌，服务器使整个令牌族失效——凭据入侵的强信号。

```swift
// ✅ 正确——带轮换支持的原子令牌刷新
// 要求：iOS 13.0+（actor 序列化保证无交错）
extension KeychainManager {
    func atomicTokenUpdate(oldAccount: String = "oauth_tokens", newTokens: OAuthTokens) throws {
        let newData = try JSONEncoder().encode(newTokens) // 在变更前编码

        var delQ: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                      kSecAttrService: self.service as CFString,
                                      kSecAttrAccount: oldAccount as CFString]
        #if os(macOS)
        delQ[kSecUseDataProtectionKeychain] = true
        #endif
        let delStatus = SecItemDelete(delQ as CFDictionary)
        guard delStatus == errSecSuccess || delStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(delStatus)
        }

        var addQ = baseQuery(account: oldAccount); addQ[kSecValueData] = newData
        let addStatus = SecItemAdd(addQ as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }
}
```

### 带 Promise 合并的刷新协调器

如果多个并发调用者检测到过期令牌，仅应触发一个刷新请求且所有调用者共享结果：

```swift
// ✅ 正确——单次刷新协调器
// 要求：iOS 13.0+
actor TokenRefreshCoordinator {

    private let keychain: KeychainManager
    private let tokenEndpoint: URL
    private var refreshTask: Task<OAuthTokens, Error>?

    init(keychain: KeychainManager, tokenEndpoint: URL) {
        self.keychain = keychain; self.tokenEndpoint = tokenEndpoint
    }

    /// 返回有效访问令牌，必要时刷新。
    func validAccessToken() async throws -> String {
        guard let data = try? await keychain.load(account: "oauth_tokens"),
              let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else {
            throw TokenError.notAuthenticated
        }
        guard tokens.shouldRefresh else { return tokens.accessToken }

        // 合并：重用进行中的刷新（如果存在）
        if let existing = refreshTask { return try await existing.value.accessToken }

        let task = Task<OAuthTokens, Error> {
            defer { refreshTask = nil }
            return try await performRefresh(currentRefreshToken: tokens.refreshToken)
        }
        refreshTask = task
        return try await task.value.accessToken
    }

    private func performRefresh(currentRefreshToken: String) async throws -> OAuthTokens {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(currentRefreshToken)".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TokenError.networkError }

        switch http.statusCode {
        case 200:
            // 解码服务器响应（access_token、refresh_token?、expires_in、token_type）
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let newTokens = OAuthTokens(
                accessToken: json["access_token"] as! String,
                refreshToken: (json["refresh_token"] as? String) ?? currentRefreshToken,
                expiresAt: Date().addingTimeInterval(json["expires_in"] as! TimeInterval),
                tokenType: json["token_type"] as! String
            )
            try await keychain.atomicTokenUpdate(newTokens: newTokens)
            return newTokens
        case 400, 401:
            try? await keychain.deleteAll()  // 刷新令牌被吊销——强制重新认证
            throw TokenError.refreshTokenExpired
        default:
            throw TokenError.serverError(http.statusCode)
        }
    }

    enum TokenError: Error {
        case notAuthenticated, refreshTokenExpired, networkError, serverError(Int)
    }
}
```

---

## 带 Keychain 缓存和 TTL 的运行时 API 密钥获取

API 密钥最安全的模式是后端代理——密钥永不到达设备。当不可行时，运行时从安全后端获取密钥并缓存在 Keychain 中带生存时间。Keychain 没有原生 TTL 机制，因此将过期元数据与密钥一起存储。

使用 App Attest（`DCAppAttestService`，iOS 14.0+）在后端签发密钥前证明 App 完整性。App 在 Secure Enclave 中生成硬件支持的密钥对，并从 Apple 请求认证对象。后端验证此对象，确保 App 未被篡改且在真实设备上运行，然后交付短期 API 密钥。

```swift
// ✅ 正确——带基于 TTL 的 Keychain 缓存的运行时密钥获取
// 要求：iOS 13.0+
actor RuntimeSecretManager {

    private struct CachedSecret: Codable {
        let value: String; let fetchedAt: Date; let ttlSeconds: TimeInterval
        var isExpired: Bool { Date().timeIntervalSince(fetchedAt) >= ttlSeconds }
    }

    private let keychain: KeychainManager
    private let secretsEndpoint: URL
    private let defaultTTL: TimeInterval
    private var memoryCache: [String: CachedSecret] = [:]

    init(keychain: KeychainManager, secretsEndpoint: URL, defaultTTL: TimeInterval = 3600) {
        self.keychain = keychain; self.secretsEndpoint = secretsEndpoint; self.defaultTTL = defaultTTL
    }

    /// 三层查找：内存 → Keychain → 网络
    func secret(forKey key: String) async throws -> String {
        if let c = memoryCache[key], !c.isExpired { return c.value }

        if let data = try? await keychain.load(account: "secret_\(key)"),
           let c = try? JSONDecoder().decode(CachedSecret.self, from: data), !c.isExpired {
            memoryCache[key] = c; return c.value
        }

        let freshValue = try await fetchFromBackend(key: key)
        let cached = CachedSecret(value: freshValue, fetchedAt: Date(), ttlSeconds: defaultTTL)
        try await keychain.save(account: "secret_\(key)", data: JSONEncoder().encode(cached))
        memoryCache[key] = cached
        return freshValue
    }

    private func fetchFromBackend(key: String) async throws -> String {
        var request = URLRequest(url: secretsEndpoint.appendingPathComponent(key))
        // 在后端签发密钥前用 App Attest (iOS 14.0+) 认证
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONDecoder().decode([String: String].self, from: data),
              let value = json["value"] else { throw SecretFetchError.serverError }
        return value
    }

    enum SecretFetchError: Error { case serverError }
}
```

---

## 登出时的全面凭据清理

安全登出必须清除每个凭据制品：访问令牌、刷新令牌、缓存的密钥、用户配置数据和内存缓存。它还必须尽可能在服务端吊销令牌。将所有认证相关 Keychain 条目分组在单个 `kSecAttrService` 值下，这样 `SecItemDelete` 可以一次调用清除它们——无遗忘的刷新令牌，无孤立的 API 密钥。

```swift
// ✅ 正确——登出时完整凭据清理
// OWASP MASVS-STORAGE-1、MASVS-STORAGE-2 合规 | iOS 13.0+
actor SessionManager {

    private let keychain = KeychainManager(service: "com.myapp.auth",
                                            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)

    func logout() async {
        // 1. 服务端吊销（尽力而为）
        if let data = try? await keychain.load(account: "oauth_tokens"),
           let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) {
            try? await revoke(token: tokens.refreshToken)
            try? await revoke(token: tokens.accessToken)
        }
        // 2. 核弹级 Keychain 清理——此服务的所有条目
        try? await keychain.deleteAll()
        // 3. 清除认证域的 cookie
        HTTPCookieStorage.shared.cookies(for: URL(string: "https://auth.example.com")!)?
            .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        // 4. 清除 URL 缓存
        URLCache.shared.removeAllCachedResponses()
    }

    private func revoke(token: String) async throws {
        var req = URLRequest(url: URL(string: "https://auth.example.com/oauth/revoke")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "token=\(token)".data(using: .utf8)
        _ = try await URLSession.shared.data(for: req)
    }
}
```

**服务端驱动的吊销信号：** 后端可通过带自定义原因码的 HTTP 401/403（如 `token_revoked`）或通过静默推送通知 (APNs) 发出吊销信号，以触以后台登出和 Keychain 清理。

---

## 密钥轮换和版本化迁移

### 按密钥类型的轮换策略

**OAuth 刷新令牌** —— 依赖服务端驱动的 RTR。Okta 的模型在每次使用时签发新刷新令牌并带可配置宽限期（0–60 秒）。如果在宽限期外重用先前失效的令牌，服务器使整个令牌族失效。

**长期 API 密钥** —— 轮换是计划事件：生成新的最低权限密钥，部署，验证操作，然后吊销旧的。维护入侵场景的应急手册。

### 版本化 Keychain 条目用于迁移

使用 `kSecAttrAccount` 键对 Keychain 条目进行版本化，以在轮换期间启用向后兼容迁移：

```swift
// ✅ 正确——轮换期间版本化 Keychain 迁移
// 要求：iOS 13.0+
actor TokenMigrationManager {

    private let keychain: KeychainManager
    private static let currentVersion = 2

    init(keychain: KeychainManager) { self.keychain = keychain }

    /// 在 App 启动时调用以迁移旧令牌格式。
    func migrateIfNeeded() async throws {
        if let _ = try? await keychain.load(account: "oauth_tokens_v2") {
            return // 已是当前版本
        }
        if let oldData = try? await keychain.load(account: "oauth_tokens") {
            let migrated = try migrateV1ToV2(oldData)
            try await keychain.save(account: "oauth_tokens_v2", data: migrated)
            try await keychain.delete(account: "oauth_tokens") // 清理旧条目
        }
    }

    private func migrateV1ToV2(_ data: Data) throws -> Data {
        // 实现版本间的格式转换
        return data
    }
}
```

### 检测被入侵的凭据

四种策略：(1) **令牌重用检测**——服务器在呈现已轮换刷新令牌时使整个令牌族失效。(2) **异常监控**——令牌使用模式中的地理或时间异常。(3) **主动刷新**——在生命周期的 75–90% 刷新令牌而非等待过期。(4) **泄露数据库检查**——AWS Cognito 等服务在认证期间对照已知泄露数据库检查凭据。

---

## 设备绑定和备份影响

使用 `ThisDeviceOnly` 变体防止凭据克隆但在设备升级时引入摩擦。因为 `ThisDeviceOnly` 密钥不可迁移，用户将 iCloud 备份恢复到新设备时不会传输它们。App 必须在首次启动时检测缺失的凭据并优雅地引导用户重新认证。

```swift
// ✅ 模式：检测设备恢复后缺失的凭据
func handleAppLaunch() async {
    do {
        let _ = try await keychain.load(account: "oauth_tokens_v2")
        // 令牌存在——正常继续
    } catch KeychainManager.KeychainError.itemNotFound {
        // 可能是全新安装或设备恢复
        // 路由到认证流程
        await presentLoginScreen()
    } catch {
        // 意外错误——记录并路由到认证
        logger.error("Keychain load failed: \(error)")
        await presentLoginScreen()
    }
}
```

**为什么不对 App 令牌使用 `kSecAttrSynchronizable`？** 设置为 `true` 会通过 iCloud Keychain 在所有受信任 Apple 设备间同步条目。虽然适合 Passwords App 管理的网站密码，但这显著增加 OAuth 令牌和 API 密钥的攻击面。省略此属性以保持密钥本地。

---

## 高价值凭据的生物识别保护

对于用户发起的高价值操作（如支付授权、查看敏感数据），添加带生物识别门控的 `SecAccessControl`。避免对需要无头后台更新的刷新令牌使用生物识别保护。

```swift
// ✅ 正确——最高 OWASP MASTG L2 合规配置
// 要求：iOS 11.3+（用于 .or 复合约束）
func createHighSecurityKeychainItem(account: String, secret: Data) throws {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        [.biometryCurrentSet, .or, .devicePasscode],
        &error
    ) else {
        throw error!.takeRetainedValue() as Error
    }

    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.myapp.auth" as CFString,
        kSecAttrAccount: account as CFString,
        kSecValueData: secret,
        kSecAttrAccessControl: accessControl,
        kSecUseDataProtectionKeychain: true
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
```

**交叉引用：** 见 `biometric-authentication.md` 了解详细的 `LAContext` 集成模式和 LAContext-only 绕过漏洞。见 `keychain-access-control.md` 了解完整可访问性类别决策树。

---

## iOS 17+ 和 18+ 现代化

**iOS 17** 引入了 `ASWebAuthenticationSession.Callback` (iOS 17.4+)，启用 HTTPS 通用链接回调而非自定义 URL 方案——更安全的重定向处理，验证域所有权。共享密码组让团队通过端到端加密的 iCloud Keychain 共享凭据。第三方凭据提供者扩展现在可以与密码一起提供 passkey。

**iOS 18** 带来了独立 Passwords App（替代终端用户的 Keychain Access）、通过 `.conditional` 注册样式自动 passkey 升级，并扩展凭据提供者扩展以支持验证码。没有引入新的 `SecItem*` API，但生态系统向 passkey 的转变意味着 Keychain 的角色正从存储密码演变为存储用于基于 WebAuthn 认证的加密密钥。

**WWDC 2024** Session 10125 "Streamline sign-in with passkey upgrades and credential managers" 详细介绍了自动 passkey 升级流程。WWDC 2021 Session 10105 引入了通过 iCloud Keychain 同步的设备上 TOTP 验证码生成，减少对基于 SMS 的 2FA 的依赖。

**Swift 6 严格并发方向：** 社区 `swift-keychain-kit` 库引入 `SecretData` 作为不可复制类型（`~Copyable`），使用 `mlock` 防止交换到磁盘并在解除分配时清零内存。虽然尚未是 Apple 框架，此模式指向 Keychain API 的发展方向：无法意外复制到不安全内存的已消费密钥。

---

## 静态分析和 CI/CD 护栏

在凭据反模式到达生产前捕获它们：

| 工具                         | 用途                                                | 集成点        |
| ---------------------------- | -------------------------------------------------- | ------------- |
| **truffleHog / gitleaks**    | 扫描源码中的硬编码密钥                              | PR/提交钩子   |
| **strings / class-dump**     | 验证编译二进制中无密钥                              | 构建后 CI 步骤|
| **SwiftLint**（自定义规则）  | 标记类令牌键的 `UserDefaults` 使用                  | 本地 + CI     |
| **Frida / Objection**        | 运行时验证 `kSecAttrAccessible` 值                  | QA / 渗透测试 |
| **MobSF**                    | 自动化网络流量和存储泄露分析                        | 动态回归门    |

**规则：** 如果静态分析在代码库或编译二进制中检测到密钥，则构建失败。

---

## OWASP MASTG 合规映射

OWASP Mobile Top 10 (2024) 将 M1（不当凭据使用）列为头号移动安全风险。MASVS v2.1.0 重组要求，MASWE（Mobile App Security Weakness Enumeration）将控制桥接到特定测试。

| 模式                                    | OWASP 控制                | MASWE 弱点                         | MASTG 测试                           |
| --------------------------------------- | ------------------------- | ---------------------------------- | ------------------------------------- |
| 带 `WhenUnlockedThisDeviceOnly` 的 Keychain | M1、M9、MASVS-STORAGE-1   | MASWE-0002、MASWE-0004、MASWE-0036 | MASTG-TEST-0299、0300、0301、0302     |
| 基于 actor 的线程安全访问               | M9、MASVS-STORAGE-1       | MASWE-0002                         | MASTG-TEST-0300                       |
| ASWebAuthenticationSession（临时）      | M1、MASVS-AUTH-1          | MASWE-0032                         | MASTG-TEST-0064                       |
| 原子令牌刷新                            | M1、MASVS-AUTH-1          | MASWE-0038                         | —                                     |
| 运行时密钥获取                          | M1、MASVS-STORAGE-1       | MASWE-0005                         | —                                     |
| 全面登出清理                            | M9、MASVS-STORAGE-2       | MASWE-0004                         | MASTG-TEST-0298                       |
| 生物识别 + `ThisDeviceOnly`             | M9、MASVS-STORAGE-2       | MASWE-0046                         | MASTG-TEST-0298、MASTG-DEMO-0043–0047 |

旧版测试标识符 MSTG-STORAGE-1 和 MSTG-STORAGE-2 映射到废弃的 MASTG-TEST-0052 和 MASTG-TEST-0053，现已被细粒度套件 MASTG-TEST-0296 至 MASTG-TEST-0314 替代。

---

## 结论

Keychain 不是可选的——它是 Apple 提供的唯一通过 Secure Enclave 加密凭据并强制执行与设备锁定状态绑定的数据保护类别的机制。三个架构决策消除大多数凭据漏洞：(1) 使用 Swift actor 作为单一 Keychain 访问点以消除令牌刷新中的竞争条件；(2) 使用 App Attest 进行 App 认证从后端代理运行时获取密钥而非嵌入二进制；(3) 将所有认证相关 Keychain 条目分组在单个 `kSecAttrService` 下，使登出可以一次调用清除所有内容。

未来轨迹——passkey、不可复制密钥类型、HTTPS 回调——强化而非替代这些基础。

---

## 总结清单

1. **仅 Keychain 存储** —— 所有令牌、API 密钥和凭据独占存储在 Keychain 中带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；永不在 `UserDefaults`、`Info.plist`、`.xcconfig` 或源码中硬编码
2. **Actor 序列化访问** —— 所有 Keychain 操作通过 Swift `actor`（或 `@globalActor`）路由以防止竞争条件和并发访问的 `errSecDuplicateItem` 错误
3. **ASWebAuthenticationSession + PKCE** —— OAuth2 流程使用 `ASWebAuthenticationSession` 带 `prefersEphemeralWebBrowserSession = true` 和 PKCE (RFC 7636)；永不 `WKWebView` 或 `SFSafariViewController`
4. **原子令牌刷新** —— 刷新令牌轮换在 actor 内原子处理：在任何变更前编码新令牌，删除旧，存储新；promise 合并防止重复刷新请求
5. **运行时密钥获取** —— API 密钥从认证后端获取（App Attest / DeviceCheck，iOS 14.0+）并缓存在 Keychain 中带应用层 TTL；三层查找：内存 → Keychain → 网络
6. **全面登出** —— 按 `kSecAttrService` 的 `deleteAll()` 一次调用清除所有凭据条目；同时在服务端吊销令牌，清除 cookie，清除 `URLCache`
7. **App 令牌不使用 `kSecAttrSynchronizable`** —— iCloud Keychain 同步是为网站密码，而非应用密钥；`ThisDeviceOnly` 变体防止备份提取
8. **设备恢复检测** —— App 检测设备恢复后缺失的 `ThisDeviceOnly` 凭据并优雅路由到重新认证
9. **版本化迁移** —— Keychain 条目通过 `kSecAttrAccount` 命名版本化（如 `oauth_tokens_v2`）以支持轮换期间的格式变更和回滚
10. **CI/CD 密钥扫描** —— 静态分析（truffleHog、gitleaks、`strings`）集成到构建管道以在部署前捕获硬编码密钥；检测到时构建失败
11. **OWASP MASTG 合规** —— 模式满足 M1、M9、MASVS-STORAGE-1、MASVS-AUTH-1 控制；用 MASTG-TEST-0298 至 0302 和动态分析（Frida/Objection）在运行时确认保护类别验证
