# 生物识别认证

> **领域范围：** SecAccessControl + LAContext 集成、LAContext-only 绕过漏洞、硬件绑定的生物识别门控、回退行为、UI 自定义、注册变更检测、线程安全。
>
> **风险等级：** CRITICAL —— #1 最危险的 AI 生成模式。单独使用的 `LAContext.evaluatePolicy()` 在运行时可被轻松绕过。

---

## 布尔门漏洞

AI 编码助手为 iOS 生物识别认证生成的最危险模式是 `LAContext.evaluatePolicy()` 用作独立认证门。这种模式出现在几乎每个教程、Stack Overflow 答案和 AI 训练语料库中——而且它**可被轻松绕过**。

攻击不需要漏洞利用。攻击者使用 Frida 或 objection hook Objective-C 回调并强制 `success = true`，完全绕过 Face ID 或 Touch ID。正式的弱点分类是 CWE-288：通过替代路径或通道的认证绕过。

OWASP MASTG 明确不通过任何仅依赖 `evaluatePolicy` 的 App（测试 MASTG-TEST-0266，要求 MSTG-AUTH-8 和 MSTG-AUTH-12）。标准规定：生物识别认证不能是事件绑定的（返回 `true`/`false`）；它必须基于解锁 keychain/keystore。

### 危险模式 — 布尔门

```swift
// ❌ 危险：用 Frida 可轻松绕过——不要用于安全
import LocalAuthentication

func authenticateUser() {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access your account"
        ) { success, authError in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true   // ← 只是可 hook 内存中的布尔
                    self.showProtectedContent()   // ← 没有解锁密钥，没有释放密钥
                }
            }
        }
    }
}
```

**为什么失败：** `evaluatePolicy()` 询问操作系统"用户认证了吗？"并在用户空间收到一个布尔答案。不涉及加密材料。没有密钥被解密。整个安全模型依赖于一个存在于可 hook 内存中的布尔。

### 攻击者如何绕过它

objection 工具（基于 Frida 构建）提供一条命令绕过：

```bash
objection -g "com.example.targetapp" explore
ios ui biometrics_bypass
```

这个 hook 监听 `-[LAContext evaluatePolicy:localizedReason:reply:]` 的调用，拦截 reply block，并将 `success` 布尔替换为 `true`。等效的原始 Frida 脚本：

```javascript
// Frida 脚本——强制 evaluatePolicy success = true
if (ObjC.available) {
  var hook = ObjC.classes.LAContext["- evaluatePolicy:localizedReason:reply:"];
  Interceptor.attach(hook.implementation, {
    onEnter: function (args) {
      var block = new ObjC.Block(args[4]);
      const callback = block.implementation;
      block.implementation = function (error, value) {
        const result = callback(1, null); // 1 = true，null = 无错误
        return result;
      };
    },
  });
}
```

objection wiki 确认了攻击边界：此绕过**对**使用 `.biometryCurrentSet` 或 `.biometryAny` 等访问控制标志保护的 keychain 条目**无效**。该边界是安全模式的整个基础。

✅ 此威胁模型中的正确模式：仅使用生物识别解锁 keychain 保护的密钥（`SecAccessControl` + `SecItemCopyMatching`），绝不作为独立布尔门。

---

## 安全模式 — 硬件绑定的密钥

正确的架构将密钥存储在 iOS keychain 中，带有生物识别访问控制。密钥的加密密钥由 Secure Enclave 持有——这是一个运行自己的微内核（sepOS）的专用处理器，拥有自己的加密内存，与应用处理器完全隔离。

当 App 请求密钥时，Secure Enclave 独立验证生物识别匹配，然后才释放解密密钥。没有可 hook 的布尔。没有有效的生物识别认证，数据在物理上无法被读取。

WWDC 2014 Session 711（"Keychain and Authentication with Touch ID"）划出了关键区别：

- **`evaluatePolicy`**："信任操作系统"——如果运行时被入侵则脆弱
- **Keychain + SecAccessControl**："信任 Secure Enclave"——ACL 在硬件内部评估

### 步骤 1 — 创建访问控制对象

```swift
import LocalAuthentication
import Security

enum BiometricKeychainError: Error {
    case accessControlCreationFailed
    case keychainOperationFailed(status: OSStatus)
    case dataConversionFailed
    case biometryNotAvailable(reason: String)
}

func createBiometricAccessControl() throws -> SecAccessControl {
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,  // 最强：需要密码，仅设备
        .biometryCurrentSet,                               // 注册变更时失效
        &error
    ) else {
        throw BiometricKeychainError.accessControlCreationFailed
    }
    return accessControl
}
```

### 步骤 2 — 存储绑定到生物识别认证的密钥

```swift
// ✅ 安全：密钥由 Secure Enclave 加密，仅在生物识别匹配时释放
func storeSecretWithBiometric(secret: Data, account: String, service: String) throws {
    let accessControl = try createBiometricAccessControl()

    // 先删除任何现有条目（add-or-update 模式）
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    let addQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service,
        kSecValueData as String: secret,
        kSecAttrAccessControl as String: accessControl,
        kSecAttrSynchronizable as String: kCFBooleanFalse  // 永不同步生物识别门控的密钥
        // 注意：不要设置 kSecAttrAccessible——它与 kSecAttrAccessControl 冲突
    ]

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw BiometricKeychainError.keychainOperationFailed(status: status)
    }
}
```

**关键细节：** 不要在同一查询中同时设置 `kSecAttrAccessible` 和 `kSecAttrAccessControl`。它们冲突——`SecAccessControl` 已经编码了可访问性级别。同时设置两者会导致 `errSecParam`。

**关键细节：** 始终对生物识别门控的密钥使用 `ThisDeviceOnly` 可访问性。`ThisDeviceOnly` 后缀确保密钥是硬件绑定的并排除在 iCloud 备份之外。跨设备同步生物识别门控的密钥会扩大攻击面。

### 步骤 3 — 检索密钥（生物识别提示自动出现）

```swift
// ✅ 安全：系统呈现生物识别提示；Secure Enclave 门控解密
func retrieveSecretWithBiometric(account: String, service: String) throws -> Data {
    let context = LAContext()
    context.localizedReason = "Authenticate to access your credentials"

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseAuthenticationContext as String: context
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
        guard let data = result as? Data else {
            throw BiometricKeychainError.dataConversionFailed
        }
        return data  // 密钥仅在 Secure Enclave 验证生物识别后返回
    case errSecItemNotFound:
        throw BiometricKeychainError.keychainOperationFailed(status: status)
    case errSecUserCanceled:
        throw BiometricKeychainError.keychainOperationFailed(status: status)
    case errSecAuthFailed:
        throw BiometricKeychainError.keychainOperationFailed(status: status)
    default:
        throw BiometricKeychainError.keychainOperationFailed(status: status)
    }
}
```

**关键洞察：** 认证和数据保护是同一操作，而非顺序操作。当 `SecItemCopyMatching` 遇到带有生物识别访问控制的条目时，系统自动呈现生物识别提示。Secure Enclave 内部验证匹配，然后才解包 AES-256-GCM 解密密钥。没有可拦截的回调。

---

## `evaluatePolicy` vs `evaluateAccessControl`

这两个 `LAContext` 方法代表了 WWDC 2014 Session 711 的两种信任模型：

**`evaluatePolicy(_:localizedReason:reply:)`** 触发生物识别认证并返回布尔。Secure Enclave 正确验证生物识别，但结果以 `true`/`false` 形式传达给用户空间。没有密钥被释放。App 基于可 hook 内存中的布尔分支。这是"信任操作系统"。

**`evaluateAccessControl(_:operation:localizedReason:reply:)`** 为特定加密操作（`.useItem`、`.useKeySign`、`.useKeyDecrypt`）评估 `SecAccessControl` 对象。与 keychain 条目一起使用时，已认证的 `LAContext` 通过 `kSecUseAuthenticationContext` 传递给 `SecItemCopyMatching`，Secure Enclave 识别先前的认证。这是"信任 Secure Enclave"。

**实践中，你很少直接调用 `evaluateAccessControl`。** 推荐流程：通过 `SecItemAdd` 用 `SecAccessControl` 存储数据，然后用 `SecItemCopyMatching` 检索。当查询遇到 ACL 保护的条目时，系统自动处理生物识别提示。

`evaluatePolicy` 的唯一合法用途是**非安全关键的 UI 门控**——决定是否显示"使用 Face ID 登录"按钮。它绝不能保护敏感数据或门控对密钥的访问。

---

## 生物识别标志选择

`SecAccessControlCreateFlags` 提供三个生物识别相关标志。选择错误是即使其他方面正确的实现中常见的错误。

### `.biometryCurrentSet` —— 银行、支付、凭据存储

将 keychain 条目绑定到存储时的**确切生物识别注册**。如果用户添加指纹、重新注册 Face ID 或移除生物识别条目，该条目将**永久不可访问**。

```swift
// ✅ 最强生物识别绑定——注册变更时失效
let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .biometryCurrentSet, nil
)
```

**权衡：** 更改生物识别的用户必须通过 App 的密码流程重新认证。通过 `LAContext.evaluationPolicyDomainState`（见下面的注册变更检测）检测注册变更并呈现优雅的重新注册。

### `.biometryAny` —— 便利功能、中等敏感度

在生物识别注册变更后存活。在受损设备上注册自己生物识别的攻击者可以访问数据。

```swift
// 在重新注册后存活——更好的 UX，较弱的安全性
let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryAny, nil
)
```

**用例：** "记住我"功能、非关键 App 锁、受益于生物识别便利但不保护财务数据的偏好设置。

### `.userPresence` —— 最大设备兼容性

当生物识别不可用时允许密码回退。较弱，因为密码容易受到肩窥攻击。

```swift
// 最广兼容性——生物识别或密码
let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    .userPresence, nil
)
```

**用例：** 无障碍优先的 App、没有生物识别硬件的设备，或作为 `.biometryCurrentSet` 的降级路径。

### 组合标志

标志可以用 `.or` 和 `.and` 连接组合：

```swift
// ✅ 强生物识别绑定带密码逃生路径
let access = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.biometryCurrentSet, .or, .devicePasscode], nil
)
```

这种组合对大多数生产 App 是实用的——强生物识别安全，当生物识别不可用时提供恢复路径。

---

## 生物识别可用性检查和优雅降级

### 不完整的可用性检查

```swift
// ❌ 错误：忽略生物识别为何失败——用户得不到指导
func checkBiometrics() -> Bool {
    let context = LAContext()
    var error: NSError?
    return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
}
```

### 完整的可用性评估

```swift
// ✅ 正确：评估每个失败原因并提供可操作指导
enum BiometricAvailability {
    case available(type: LABiometryType)
    case notEnrolled          // 硬件存在，未注册生物识别
    case lockedOut            // 失败尝试过多——需要密码
    case notAvailable         // 无硬件或受 MDM 限制
    case passcodeNotSet       // 无设备密码——生物识别需要一个
}

func evaluateBiometricAvailability() -> BiometricAvailability {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        return .available(type: context.biometryType)
    }

    guard let laError = error as? LAError else { return .notAvailable }

    switch laError.code {
    case .biometryNotEnrolled:
        return .notEnrolled     // → "在设置中启用 Face ID"
    case .biometryLockout:
        return .lockedOut       // → 提示密码以重置传感器
    case .biometryNotAvailable:
        return .notAvailable    // → 完全隐藏生物识别 UI
    case .passcodeNotSet:
        return .passcodeNotSet  // → "设置密码以使用 Face ID"
    default:
        return .notAvailable
    }
}
```

### 优雅降级流程

```swift
// ✅ 从生物识别 → 密码 → 密码登录降级
func authenticateWithGracefulDegradation() async throws -> Data {
    let availability = evaluateBiometricAvailability()

    switch availability {
    case .available:
        return try retrieveSecretWithBiometric(account: "user", service: "com.app.auth")

    case .lockedOut:
        // 生物识别锁定——使用 .userPresence 条目进行密码回退
        return try retrieveSecretWithPasscodeFallback(account: "user", service: "com.app.auth")

    case .notEnrolled:
        throw BiometricKeychainError.biometryNotAvailable(
            reason: "Please enable Face ID in Settings > Face ID & Passcode"
        )

    case .notAvailable, .passcodeNotSet:
        throw BiometricKeychainError.biometryNotAvailable(
            reason: "Biometric authentication is not available on this device"
        )
    }
}
```

**关键：** 不处理 `.biometryLockout` 会困住用户。App 无法绕过此锁定——用户必须成功输入设备密码以重新启用生物识别传感器。如果你的 App 没有回退，用户将被永久锁定，直到他们离开你的 App 并用密码解锁。

**重要：** `canEvaluatePolicy()` 严格用于预检 UI 决策（显示或隐藏"使用 Face ID 登录"按钮）。它绝不能用作安全控制。

---

## 注册变更检测

使用 `.biometryCurrentSet` 时，主动检测注册变更，这样你的 App 可以引导用户完成重新注册，而不是呈现晦涩的 keychain 错误。

```swift
// ✅ 通过 domainState 检测生物识别注册变更
class BiometricEnrollmentMonitor {
    private let domainStateKey = "com.app.biometric.domainState"

    /// 在成功的生物识别设置后调用以快照当前注册
    func saveCurrentEnrollment() {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return }

        // domainState 在生物识别注册变更时改变
        if let domainState = context.evaluatedPolicyDomainState {
            UserDefaults.standard.set(domainState, forKey: domainStateKey)
        }
    }

    /// 在 App 启动或生物识别检索前调用
    func hasEnrollmentChanged() -> Bool {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return true  // 无法评估——视为已变更
        }

        guard let currentState = context.evaluatedPolicyDomainState,
              let savedState = UserDefaults.standard.data(forKey: domainStateKey) else {
            return true  // 无保存状态——首次运行或数据已清除
        }

        return currentState != savedState
    }
}
```

**注意：** `evaluatedPolicyDomainState` 是一个不透明的 `Data` blob。它在生物识别注册变更时改变但不泄露关于生物识别本身的信息。将它存储在 `UserDefaults`（而非 keychain）中，因为它不敏感——仅用于变更检测。

---

## 线程安全和 async/await

带有生物识别访问控制的 `SecItemCopyMatching` **会阻塞调用线程**直到用户完成认证。绝不在 `@MainActor` 或主线程上运行它。

`LAContext.evaluatePolicy` 的遗留完成处理器在未指定线程上下文的私有队列上执行。从此回调直接更新 UI 会导致崩溃，特别是在 iOS 18 上线程严格性增加时。

### Actor 隔离的生物识别 Keychain (iOS 15+)

```swift
@available(iOS 15.0, *)
actor BiometricKeychain {

    func retrieveSecret(account: String, service: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let context = LAContext()
                context.localizedReason = "Authenticate to access your account"

                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: account,
                    kSecAttrService as String: service,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseAuthenticationContext as String: context
                ]

                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                switch status {
                case errSecSuccess:
                    if let data = result as? Data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: BiometricKeychainError.dataConversionFailed)
                    }
                case errSecUserCanceled, errSecAuthFailed:
                    continuation.resume(throwing: BiometricKeychainError.keychainOperationFailed(status: status))
                default:
                    continuation.resume(throwing: BiometricKeychainError.keychainOperationFailed(status: status))
                }
            }
        }
    }
}
```

### SwiftUI ViewModel 集成

```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?

    private let keychain = BiometricKeychain()

    func authenticate() {
        Task {
            do {
                let secret = try await keychain.retrieveSecret(
                    account: "user_token",
                    service: "com.myapp.auth"
                )
                self.isAuthenticated = true
                self.processToken(secret)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
```

**关于原生 async 的说明：** `LAContext` 在 iOS 15 中获得了 `evaluatePolicy(_:localizedReason:) async throws -> Bool`。然而，这仅与非安全关键的 UI 门控用例相关。对于安全的 keychain 模式，按上述方式包装 `SecItemCopyMatching`——SecItem\* API 没有原生 async 重载。

---

## Secure Enclave 支持的密钥与生物识别保护

对于非对称密钥操作（签名、密钥协商），通过 CryptoKit 将 Secure Enclave 密钥生成与生物识别访问控制结合。私钥**永不离开 Secure Enclave**——所有操作在硬件中发生。

```swift
// ✅ Secure Enclave P-256 密钥带生物识别保护 (WWDC 2019-709)
let accessControl = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)!

let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
    accessControl: accessControl
)

// 签名自动触发生物识别提示
let signature = try privateKey.signature(for: dataToSign)
```

Frida 在应用处理器上的用户空间运行，对 Secure Enclave 的内部状态零访问。Secure Enclave 的内存用其自己的 AES 引擎加密。即使是内核级别的入侵也无法提取密钥。

---

## SDLC 控制 — 在 CI 中捕获反模式

由于 AI 编码助手频繁生成易受攻击的 `evaluatePolicy` 模式，团队应实现自动化检测：

**概念性 SAST 规则（`INSECURE_BIOMETRIC_GATE`）：** 识别所有对 `LAContext.evaluatePolicy` 的调用。如果 `success` 布尔直接门控对资源的访问，且同一流程中没有使用 `SecAccessControl` 对象的对应 `SecItemCopyMatching`，则标记该代码。

**安全审查签署标准：**

1. 零个门控敏感操作的独立 `LAContext.evaluatePolicy` 实例
2. 存在使用 `ThisDeviceOnly` 可访问性的 `SecItemAdd` 与 `kSecAttrAccessControl` 的证据
3. 文档化证明 objection 绕过（`ios ui biometrics_bypass`）无法解锁受保护数据
4. 所有 `LAError` 情况都处理并优雅降级
5. 如果使用 `.biometryCurrentSet`，存在经过测试的重新注册恢复流程

---

## 动态验证 — 证明绕过抵抗

仅静态代码审查不够。验证需要动态测试：

**测试流程：** 在越狱或插桩设备上，注入 Frida 脚本 hook `-[LAContext evaluatePolicy:localizedReason:reply:]` 并强制 `success = true`。

**通过标准：** 尽管回调被篡改，App 仍阻止访问受保护数据。密钥保持锁定，因为 `SecAccessControl` + Secure Enclave 强制执行独立于布尔。

**失败标准：** hook 强制成功后 App 授予访问权限。这证明依赖于易受攻击的布尔门。

---

## 关键参考

- **WWDC 2014 Session 711** —— "Keychain and Authentication with Touch ID"：介绍了两种信任模型（evaluatePolicy vs keychain+ACL）
- **WWDC 2019 Session 709** —— "Cryptography and Your Apps"：CryptoKit + Secure Enclave 密钥生成与访问控制
- **Apple Platform Security Guide** —— Secure Enclave 架构、keychain 加密链（元数据密钥 + 密钥密钥）、硬件中的 ACL 评估
- **OWASP MASTG MSTG-AUTH-8** —— 生物识别认证不能是事件绑定的
- **OWASP MASTG MSTG-AUTH-12** —— 必须验证生物识别机制的完整性
- **OWASP MASTG MASTG-TEST-0266** —— 本地认证绕过测试
- **objection wiki** —— "Understanding the iOS Biometrics Bypass"：确认 SecAccessControl 的攻击边界
- **TN3137** —— "On Mac Keychain APIs and implementations"（macOS keychain 统一）

---

## 交叉引用

- `keychain-fundamentals.md` —— keychain 绑定生物识别流程使用的 SecItem CRUD 模式
- `keychain-access-control.md` —— `SecAccessControlCreateWithFlags`、可访问性常量和标志组合规则
- `secure-enclave.md` —— 通过 `SecAccessControl` 带生物识别门控的硬件支持密钥
- `common-anti-patterns.md` —— 反模式 #3（仅 LAContext 生物识别门）
- `credential-storage-patterns.md` —— 高价值凭据（OAuth 令牌、API 密钥）的生物识别保护
- `testing-security-code.md` —— 生物识别流程的基于协议的 mock、LAContext 测试策略
- `compliance-owasp-mapping.md` —— M3（不安全认证/授权）生物识别要求

---

## 总结清单

1. **没有独立布尔门** —— `LAContext.evaluatePolicy()` 永远不是敏感数据的唯一认证机制；密钥始终绑定到 keychain + `SecAccessControl`
2. **硬件门控的密钥** —— 所有由生物识别保护的敏感数据使用 `SecAccessControlCreateWithFlags`，由 Secure Enclave 强制执行 ACL
3. **正确的标志选择** —— `.biometryCurrentSet` 用于高安全性（银行、支付）；`.biometryAny` 用于便利；`.userPresence` 用于广泛兼容性或回退
4. **没有 kSecAttrAccessible 冲突** —— `kSecAttrAccessible` 和 `kSecAttrAccessControl` 永不在同一 keychain 条目上设置
5. **ThisDeviceOnly 可访问性** —— 生物识别门控的密钥使用 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` 或 `WhenUnlockedThisDeviceOnly`；永不可同步
6. **完整的错误处理** —— 处理所有 `LAError` 代码：`.biometryNotEnrolled`、`.biometryLockout`、`.biometryNotAvailable`、`.passcodeNotSet`、`.userCancel`、`.userFallback`
7. **优雅降级** —— 当生物识别不可用或锁定时，App 提供回退路径（密码或密码登录）
8. **注册变更检测** —— 使用 `.biometryCurrentSet` 时监控 `evaluatedPolicyDomainState`；实现重新注册流程
9. **线程安全** —— 带生物识别 ACL 的 `SecItemCopyMatching` 永不在 `@MainActor` 上运行；actor 隔离或分发到后台队列
10. **动态验证** —— objection/Frida 绕过测试确认 hook `evaluatePolicy` 回调时受保护数据仍不可访问
11. **SAST/linting** —— CI 管道包含规则以标记没有对应 `SecAccessControl` keychain 操作的独立 `evaluatePolicy`
