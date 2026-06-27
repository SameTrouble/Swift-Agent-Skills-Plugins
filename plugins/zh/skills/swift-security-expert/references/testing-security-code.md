# 测试 Keychain、CryptoKit 和生物识别代码

> 范围：跨模拟器、CI 运行器和物理设备验证 keychain、CryptoKit 和生物识别安全代码的单元、集成和 CI 模式。

**基于协议的抽象是可测试安全代码最重要的模式。** 将 Security framework 调用包装在 Swift 协议后，让你为单元测试注入内存 mock，同时将真实 keychain 集成测试保留给物理设备。核心挑战是 keychain 行为在三种环境间差异巨大——Xcode 模拟器、CI 运行器和物理设备——忽略这些差异的测试产生不稳定失败、崩溃或虚假信心。

本参考涵盖 mock 设计、CryptoKit 往返测试、Secure Enclave 保护、生物识别 mock、CI/CD keychain 创建、模拟器限制、Swift Testing 框架模式、变异测试和 OWASP MASTG 验证。所有代码针对 Swift 5.9+/6.0、iOS 17–18+，在适用处带 iOS 26 后量子说明。

关键来源：Apple TN3137 "On Mac keychain APIs and implementations"、WWDC19-413 "Testing in Xcode"、WWDC24-10179/10195 "Meet/Go further with Swift Testing"、Apple Platform Security Guide、OWASP MASTG。

---

## 基于协议的 Keychain 抽象

可测试 keychain 代码的基础是抽象四个 Security framework 操作的协议。每个触及 keychain 的视图模型、服务或管理器都依赖此协议，而非直接依赖 Security framework。

### KeychainServiceProtocol 带真实和 Mock 实现

```swift
import Foundation
import Security

enum KeychainError: Error, Equatable {
    case duplicateItem
    case itemNotFound
    case authFailed
    case interactionNotAllowed
    case unexpectedData
    case unhandledError(status: OSStatus)

    init(status: OSStatus) {
        switch status {
        case errSecDuplicateItem:          self = .duplicateItem
        case errSecItemNotFound:           self = .itemNotFound
        case errSecAuthFailed:             self = .authFailed
        case errSecInteractionNotAllowed:  self = .interactionNotAllowed
        default:                           self = .unhandledError(status: status)
        }
    }
}

protocol KeychainServiceProtocol: Sendable {
    func save(_ data: Data, forKey key: String) throws
    func read(forKey key: String) throws -> Data?
    func update(_ data: Data, forKey key: String) throws
    func delete(forKey key: String) throws
    func deleteAll() throws
}
```

真实 `KeychainService` 实现用 add-or-update 模式和正确 `OSStatus` 映射包装 `SecItem*` 调用（见 `keychain-fundamentals.md` 了解完整实现）。关键点：`save` 先尝试更新以避免 `errSecDuplicateItem`；`delete` 将 `errSecItemNotFound` 视为成功；类符合 `@unchecked Sendable` 带不可变存储属性。

mock 用字典替代 Security framework。到处运行——模拟器、CI 甚至 Linux——零权限要求。支持可注入错误和调用计数：

```swift
final class MockKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    var storage: [String: Data] = [:]
    var saveCallCount = 0
    var readCallCount = 0
    var deleteCallCount = 0
    var errorToThrow: KeychainError?

    func save(_ data: Data, forKey key: String) throws {
        if let error = errorToThrow { throw error }
        saveCallCount += 1
        storage[key] = data
    }

    func read(forKey key: String) throws -> Data? {
        if let error = errorToThrow { throw error }
        readCallCount += 1
        return storage[key]
    }

    func update(_ data: Data, forKey key: String) throws {
        if let error = errorToThrow { throw error }
        guard storage[key] != nil else { throw KeychainError.itemNotFound }
        storage[key] = data
    }

    func delete(forKey key: String) throws {
        if let error = errorToThrow { throw error }
        storage.removeValue(forKey: key)
        deleteCallCount += 1
    }

    func deleteAll() throws {
        if let error = errorToThrow { throw error }
        storage.removeAll()
    }
}
```

业务逻辑仅依赖协议——永不直接依赖 `SecItem*`：

```swift
final class AuthenticationManager {
    private let keychain: KeychainServiceProtocol

    init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    func storeToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try keychain.save(data, forKey: "auth_token")
    }

    func retrieveToken() throws -> String? {
        guard let data = try keychain.read(forKey: "auth_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

---

## AI 生成器在 Keychain 测试中犯的七个错误

两个研究提供商独立识别了重叠的反模式。此合并列表涵盖完整集合：

**1. 使用真实 keychain 但不清理的测试。** 直接调用 `SecItemAdd` 的测试在运行间留下状态。第二次运行以 `errSecDuplicateItem` (-25299) 失败。AI 生成器很少包含 `setUp`/`tearDown` 清理。

**2. 假设 Secure Enclave 在模拟器上存在。** `SecureEnclave.isAvailable` 在每个模拟器上返回 `false`。直接调用 `SecureEnclave.P256.Signing.PrivateKey()` 的测试在模拟器上抛出 `CryptoKitError` 并使 CI 崩溃。

**3. 不测试错误路径。** 真实 keychain 代码必须处理 `errSecDuplicateItem` (-25299)、`errSecItemNotFound` (-25300)、`errSecAuthFailed` (-25293) 和 `errSecInteractionNotAllowed` (-25308)。AI 生成器几乎从不测试这些失败模式。

**4. 假设生物识别硬件。** 实例化真实 `LAContext` 并断言 `canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` 返回 `true` 的测试在无生物识别硬件的模拟器上失败。

**5. 缺少测试宿主 App。** 自 Xcode 9 起，iOS 模拟器上的测试 bundle 需要宿主 App 才能访问 keychain。没有它，`SecItemAdd` 返回 `-25300` 或 `-34018`。AI 生成器从不提及此要求。

**6. 无 service/account 范围。** 省略 `kSecAttrService` 的测试匹配来自其他测试甚至其他 App 的条目。测试中的每个 keychain 操作必须使用唯一的、测试特定的 service 标识符。

**7. 混淆数据保护 keychain 与基于文件的 keychain。** 根据 Apple TN3137，macOS 有两种 keychain 实现。`security` CLI 与基于文件的 keychain 工作；iOS App 使用数据保护 keychain。使用 `security create-keychain` 的 CI 脚本为 `SecItemAdd` 目标创建错误类型。

---

## 模拟器 vs 设备测试矩阵

理解确切什么在哪里工作防止整类测试失败：

| 功能                                                       | 模拟器                             | 物理设备              |
| ---------------------------------------------------------- | ---------------------------------- | --------------------- |
| Keychain CRUD（`SecItemAdd` 等）                           | ✅ 工作                             | ✅ 工作               |
| CryptoKit 软件加密 (AES-GCM、ChaChaPoly、P256、SHA256)     | ✅ 软件                             | ✅ 硬件加速           |
| `kSecAttrAccessible` 值                                    | ✅ 接受但非硬件强制                 | ✅ 硬件强制           |
| `SecureEnclave.isAvailable`                                | 返回 **false**                      | 返回 **true** (A7+)   |
| `SecureEnclave.P256.Signing.PrivateKey()`                  | ❌ 抛出                             | ✅ 工作               |
| 受保护条目上的生物识别提示                                 | ❌ 跳过——静默返回值                 | ✅ 显示提示           |
| `LAContext.canEvaluatePolicy(.biometrics)`                 | 返回 **false**                      | 注册时返回 **true**   |
| 通过 Xcode 菜单的 Face ID 模拟                              | ✅ 仅手动                           | N/A（真实硬件）       |
| 后量子 (ML-KEM、ML-DSA) iOS 26+                            | ✅ 软件 (iOS 26 运行时)             | ✅ 工作               |

**关键微妙之处：** 在模拟器上，带 `kSecAttrAccessControl` 和生物识别标志保护的 keychain 条目返回其值而不显示生物识别提示。存储生物识别保护条目并读取它们的模拟器测试静默成功，给出生物识别门工作正常的虚假信心。

### 条件编译和运行时保护

```swift
// 编译时：在模拟器上排除 SE 代码
#if targetEnvironment(simulator)
    let signingKey = SoftwareSigningKey()
#else
    let signingKey = SecureEnclave.isAvailable
        ? try SecureEnclaveSigningKey()
        : SoftwareSigningKey()
#endif

// XCTest 中的运行时跳过
func testDeviceOnlyFeature() throws {
    #if targetEnvironment(simulator)
    throw XCTSkip("Requires physical device")
    #endif
    // 这里是仅设备测试代码
}

// 通过 ProcessInfo 的运行时检测
struct EnvironmentDetector {
    static var isSimulator: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
```

---

## 基本测试模式

### 真实 Keychain 测试的 setUp/tearDown 清理

```swift
final class KeychainIntegrationTests: XCTestCase {
    private let testService = "com.tests.keychain-integration"
    private var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        keychain = KeychainService(service: testService)
        try? keychain.deleteAll()  // 干净状态
    }

    override func tearDown() {
        try? keychain.deleteAll()  // 不留痕迹
        super.tearDown()
    }

    func testSaveAndRetrieveToken() throws {
        let token = "test-jwt-token-12345"
        try keychain.save(token.data(using: .utf8)!, forKey: "access_token")
        let retrieved = try keychain.read(forKey: "access_token")
        XCTAssertEqual(String(data: retrieved!, encoding: .utf8), token)
    }
}
```

### 无清理——跨运行不稳定

```swift
// ❌ 不正确：无清理，无隔离
final class BadKeychainTests: XCTestCase {
    func testSaveToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "token",
            kSecValueData as String: "secret".data(using: .utf8)!
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)
        // 第一次运行：通过 ✅
        // 第二次运行：以 errSecDuplicateItem (-25299) 失败 ❌
    }
}
```

### 带注入失败的错误路径测试

```swift
final class KeychainErrorPathTests: XCTestCase {
    var mockKeychain: MockKeychainService!
    var authManager: AuthenticationManager!

    override func setUp() {
        mockKeychain = MockKeychainService()
        authManager = AuthenticationManager(keychain: mockKeychain)
    }

    func testStoreToken_whenDuplicateItem_throwsExpectedError() {
        mockKeychain.errorToThrow = .duplicateItem
        XCTAssertThrowsError(try authManager.storeToken("token")) { error in
            XCTAssertEqual(error as? KeychainError, .duplicateItem)
        }
    }

    func testRetrieveToken_whenAuthFailed_throwsError() {
        mockKeychain.errorToThrow = .authFailed
        XCTAssertThrowsError(try authManager.retrieveToken()) { error in
            XCTAssertEqual(error as? KeychainError, .authFailed)
        }
    }

    func testRetrieveToken_whenInteractionNotAllowed_throwsError() {
        // 模拟最常见 CI 失败场景
        mockKeychain.errorToThrow = .interactionNotAllowed
        XCTAssertThrowsError(try authManager.retrieveToken()) { error in
            XCTAssertEqual(error as? KeychainError, .interactionNotAllowed)
        }
    }
}
```

### CryptoKit 往返测试（模拟器安全）

所有 CryptoKit 软件操作在模拟器上工作。这些测试到处运行：

```swift
import XCTest
import CryptoKit

final class CryptoKitTests: XCTestCase {

    func testAESGCMRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Sensitive credentials".data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        let ciphertext = sealedBox.combined!
        XCTAssertNotEqual(ciphertext, plaintext)

        let reopened = try AES.GCM.SealedBox(combined: ciphertext)
        let decrypted = try AES.GCM.open(reopened, using: key)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESGCMWrongKeyFails() throws {
        let correctKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal("secret".data(using: .utf8)!, using: correctKey)
        XCTAssertThrowsError(try AES.GCM.open(sealed, using: wrongKey))
    }

    func testP256SignVerify() throws {
        let privateKey = P256.Signing.PrivateKey()
        let data = "Message to authenticate".data(using: .utf8)!
        let signature = try privateKey.signature(for: data)
        XCTAssertTrue(privateKey.publicKey.isValidSignature(signature, for: data))

        let tampered = "Tampered message".data(using: .utf8)!
        XCTAssertFalse(privateKey.publicKey.isValidSignature(signature, for: tampered))
    }

    func testCurve25519KeyAgreement() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let aliceShared = try alice.sharedSecretFromKeyAgreement(with: bob.publicKey)
        let bobShared = try bob.sharedSecretFromKeyAgreement(with: alice.publicKey)

        let aliceKey = aliceShared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
        let bobKey = bobShared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)

        // 双方都能解密彼此的消息
        let sealed = try AES.GCM.seal("test".data(using: .utf8)!, using: aliceKey)
        XCTAssertEqual(try AES.GCM.open(sealed, using: bobKey), "test".data(using: .utf8)!)
    }
}
```

**iOS 26 注意：** 后量子密码学 (ML-KEM、ML-DSA) 从 iOS 26 起通过 CryptoKit 可用。用 `@available(iOS 26, *)` 保护这些测试并使用相同往返模式。基于软件的 PQC 在模拟器上工作（见 `cryptokit-public-key.md`）。

---

## Secure Enclave 测试策略 — 协议回退

> **交叉引用矛盾：** 一个研究来源使用返回 `P256.Signing.PrivateKey` 的函数用于 SE 和软件路径。这是类型错误——`SecureEnclave.P256.Signing.PrivateKey` 和 `P256.Signing.PrivateKey` 是不同类型。正确方法是基于协议的抽象：

### 带 SE/软件实现的 SigningKeyProvider 协议

```swift
import CryptoKit

protocol SigningKeyProvider {
    func sign(_ data: Data) throws -> Data
    func publicKeyData() -> Data
}

final class SecureEnclaveSigningKey: SigningKeyProvider {
    private let key: SecureEnclave.P256.Signing.PrivateKey

    init() throws {
        guard SecureEnclave.isAvailable else {
            throw KeychainError.unhandledError(status: errSecUnimplemented)
        }
        self.key = try SecureEnclave.P256.Signing.PrivateKey()
    }

    func sign(_ data: Data) throws -> Data {
        try key.signature(for: data).derRepresentation
    }

    func publicKeyData() -> Data { key.publicKey.derRepresentation }
}

final class SoftwareSigningKey: SigningKeyProvider {
    private let key = P256.Signing.PrivateKey()

    func sign(_ data: Data) throws -> Data {
        try key.signature(for: data).derRepresentation
    }

    func publicKeyData() -> Data { key.publicKey.derRepresentation }
}

struct SigningKeyFactory {
    static func make() -> SigningKeyProvider {
        if SecureEnclave.isAvailable,
           let seKey = try? SecureEnclaveSigningKey() {
            return seKey
        }
        return SoftwareSigningKey()
    }
}
```

### 测试 Secure Enclave 代码

```swift
// ❌ 不正确：在模拟器和 CI 上崩溃
func testSecureEnclaveSigning_BROKEN() throws {
    let key = try SecureEnclave.P256.Signing.PrivateKey() // 在模拟器上抛出
    let sig = try key.signature(for: "data".data(using: .utf8)!)
    XCTAssertTrue(key.publicKey.isValidSignature(sig, for: "data".data(using: .utf8)!))
}

// ✅ 正确：SE 不可用时优雅跳过
func testSecureEnclaveSigning_withGuard() throws {
    try XCTSkipUnless(SecureEnclave.isAvailable,
                      "Secure Enclave not available — skipping on simulator")
    let key = try SecureEnclave.P256.Signing.PrivateKey()
    let data = "authenticated payload".data(using: .utf8)!
    let sig = try key.signature(for: data)
    XCTAssertTrue(key.publicKey.isValidSignature(sig, for: data))
}

// ✅ 正确：基于协议的测试到处运行
func testSigningWithFallback() throws {
    let signer = SigningKeyFactory.make()
    let data = "payload".data(using: .utf8)!
    let sigBytes = try signer.sign(data)
    XCTAssertFalse(sigBytes.isEmpty)

    let publicKey = try P256.Signing.PublicKey(derRepresentation: signer.publicKeyData())
    let signature = try P256.Signing.ECDSASignature(derRepresentation: sigBytes)
    XCTAssertTrue(publicKey.isValidSignature(signature, for: data))
}
```

---

## 生物识别流程测试 — LAContext Mock

将 `LAContext` 包装在协议后以在测试中完全控制生物识别结果。或者直接子类化 `LAContext`（更简单但耦合更紧）。

### 基于协议的方法（首选）

```swift
import LocalAuthentication

protocol BiometricAuthContext {
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String,
                        reply: @escaping (Bool, Error?) -> Void)
}

extension LAContext: BiometricAuthContext {}

final class BiometricAuthManager {
    private let context: BiometricAuthContext

    init(context: BiometricAuthContext = LAContext()) {
        self.context = context
    }

    var isBiometricsAvailable: Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        guard isBiometricsAvailable else {
            completion(.failure(LAError(.biometryNotAvailable)))
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: reason) { success, error in
            completion(success ? .success(()) : .failure(error ?? LAError(.authenticationFailed)))
        }
    }
}

final class MockBiometricContext: BiometricAuthContext {
    var canEvaluateResult = true
    var evaluateResult = true
    var evaluateError: Error?
    var evaluateCalled = false

    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        canEvaluateResult
    }

    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String,
                        reply: @escaping (Bool, Error?) -> Void) {
        evaluateCalled = true
        reply(evaluateResult, evaluateError)
    }
}
```

### 要覆盖的生物识别场景

| 场景     | canEvaluate | evaluatePolicy | 错误                  | 预期 App 行为                 |
| -------- | ----------- | -------------- | --------------------- | ----------------------------- |
| 成功     | true        | true           | nil                   | 继续                          |
| 用户取消 | true        | false          | `.userCancel`         | 重试或优雅中止                |
| 锁定     | true        | false          | `.biometryLockout`    | 回退到密码                    |
| 未注册   | false       | n/a            | `.biometryNotEnrolled`| 显示注册指导                  |

```swift
func testBiometricAuthSuccess() {
    let mock = MockBiometricContext()
    mock.canEvaluateResult = true
    mock.evaluateResult = true
    let manager = BiometricAuthManager(context: mock)

    let exp = expectation(description: "auth")
    manager.authenticate(reason: "Test") { result in
        if case .failure = result { XCTFail("Expected success") }
        exp.fulfill()
    }
    waitForExpectations(timeout: 1)
    XCTAssertTrue(mock.evaluateCalled)
}

func testBiometricAuthUnavailable() {
    let mock = MockBiometricContext()
    mock.canEvaluateResult = false
    let manager = BiometricAuthManager(context: mock)

    let exp = expectation(description: "unavailable")
    manager.authenticate(reason: "Test") { result in
        if case .success = result { XCTFail("Expected failure") }
        exp.fulfill()
    }
    waitForExpectations(timeout: 1)
    XCTAssertFalse(mock.evaluateCalled)  // 不应尝试认证
}
```

---

## CI/CD 管道配置

在 CI 中运行 keychain 测试是最容易出错的部分。`-25308`（`errSecInteractionNotAllowed`）错误是最常见 CI 失败——keychain 锁定或在无头环境中需要 GUI 交互。

### GitHub Actions

```yaml
name: iOS CI
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v5
      - name: Create temporary keychain
        env:
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH
          # 导入证书 + 关键分区列表步骤
          echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $RUNNER_TEMP/cert.p12
          security import $RUNNER_TEMP/cert.p12 -P "$P12_PASSWORD" \
            -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
          security set-key-partition-list -S apple-tool:,apple: \
            -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
      - name: Run simulator-safe tests
        run: |
          xcodebuild test -scheme MyApp \
            -destination 'platform=iOS Simulator,name=iPhone 16' \
            -testPlan CITests
      - name: Cleanup
        if: always()
        run: security delete-keychain $RUNNER_TEMP/app-signing.keychain-db
```

**`security set-key-partition-list` 必须在导入证书后调用**——这是大多数人遗漏的步骤。没有它，`codesign` 无限期挂起等待 GUI 提示。导入上的 `-A` 标志授予所有应用访问，CI 中必需。

**Xcode Cloud：** 使用临时环境——无手动 `security create-keychain`。Apple 自动管理签名。确保启用 Keychain Sharing 能力。SPM 尝试保存凭据时 `-25308` 错误常见。

**Fastlane：** `setup_ci` 创建临时 `fastlane_tmp_keychain` 并设为默认。在自托管运行器上，这可能干扰宿主机的 keychain。

```ruby
lane :ci_test do
  setup_ci(timeout: 3600)
  sync_code_signing(type: "development", readonly: is_ci)
  run_tests(scheme: "MyApp", testplan: "CITests", device: "iPhone 16")
end
```

### 常见 CI 错误参考

| 错误                         | OSStatus | 原因                                 | 修复                                             |
| ---------------------------- | -------- | ------------------------------------ | ------------------------------------------------ |
| `errSecInteractionNotAllowed` | -25308   | keychain 锁定 / 需要 GUI             | 解锁 keychain + `set-key-partition-list`         |
| `errSecMissingEntitlement`    | -34018   | 无 keychain-access-groups 权限       | 向测试宿主 App 添加权限                          |
| `errSecItemNotFound`          | -25300   | 无测试宿主或缺少权限                 | 使用带 keychain 能力的测试宿主 App               |
| `errSecInternalComponent`     | -67585   | 导入后未设置分区列表                 | 证书导入后调用 `set-key-partition-list`          |
| 未找到默认 keychain           | -25307   | CI 运行器上无默认 keychain           | 创建并设置默认 keychain                          |

### 测试宿主 App 要求

自 Xcode 9 起，iOS 模拟器上的测试 bundle 需要宿主 App 才能访问 keychain。没有它，`SecItemAdd` 返回 `-25300` 或 `-34018`。创建最小 iOS App 目标，启用 Keychain Sharing 能力，并将测试目标的 **Test Host** 和 **Bundle Loader** 构建设置指向它。

---

## Xcode 测试计划 — 分离模拟器和设备

为 CI/设备分离创建两个测试计划：

- **CITests.xctestplan**：仅使用 `MockKeychainService` 和模拟器安全 CryptoKit 的测试。跳过集成、生物识别和 SE 测试。
- **DeviceTests.xctestplan**：真实 keychain 集成、Secure Enclave 和生物识别硬件测试。需要物理设备。

```bash
# CI：每次推送时模拟器安全测试
xcodebuild test -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -testPlan CITests

# 夜间：设备农场运行所有
xcodebuild test -scheme MyApp \
  -destination 'platform=iOS,id=DEVICE_UDID' \
  -testPlan DeviceTests
```

---

## Swift Testing 框架模式

Swift Testing (WWDC24) 引入标签、特征和参数化测试，很好地映射到安全测试组织：

```swift
import Testing
@testable import MyApp

extension Tag {
    @Tag static var keychain: Self
    @Tag static var deviceOnly: Self
    @Tag static var ciSafe: Self
}

@Suite(.serialized, .tags(.keychain))
struct KeychainTests {

    @Test("Save and retrieve round-trip", .tags(.ciSafe))
    func saveAndRetrieve() throws {
        let mock = MockKeychainService()
        let manager = AuthenticationManager(keychain: mock)
        try manager.storeToken("test-token")
        let result = try #require(try manager.retrieveToken())
        #expect(result == "test-token")
    }

    @Test("Device-only: real keychain integration",
          .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil),
          .tags(.deviceOnly))
    func realKeychainIntegration() throws {
        let keychain = KeychainService(service: "com.test.swift-testing")
        try keychain.deleteAll()
        defer { try? keychain.deleteAll() }
        try keychain.save("token".data(using: .utf8)!, forKey: "key")
        let data = try #require(try keychain.read(forKey: "key"))
        #expect(String(data: data, encoding: .utf8) == "token")
    }

    @Test("Parameterized error paths",
          arguments: [
              KeychainError.duplicateItem,
              KeychainError.itemNotFound,
              KeychainError.authFailed,
              KeychainError.interactionNotAllowed
          ])
    func errorPathHandling(expectedError: KeychainError) {
        let mock = MockKeychainService()
        mock.errorToThrow = expectedError
        #expect(throws: KeychainError.self) {
            try mock.read(forKey: "any-key")
        }
    }
}
```

`.serialized` 特征确保修改共享状态的 keychain 测试顺序运行。标签与测试计划集成用于过滤——`.ciSafe` 测试在 CI 中运行，`.deviceOnly` 测试在设备农场上运行。

---

## 高级模式

### 迁移测试：UserDefaults 到 Keychain

迁移代码是安全关键的——静默失败将凭据留在 UserDefaults（见 `migration-legacy-stores.md`）。测试中的类接受两个存储的注入依赖：

```swift
final class StorageMigrationManager {
    private let defaults: UserDefaults
    private let keychain: KeychainServiceProtocol

    init(defaults: UserDefaults = .standard,
         keychain: KeychainServiceProtocol) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func migrateIfNeeded() throws {
        let version = defaults.integer(forKey: "migration_version")
        if version < 1 {
            if let token = defaults.string(forKey: "auth_token"),
               let data = token.data(using: .utf8) {
                try keychain.save(data, forKey: "auth_token")
                defaults.removeObject(forKey: "auth_token")
            }
        }
        defaults.set(1, forKey: "migration_version")
    }
}
```

用隔离的 `UserDefaults(suiteName:)` 和 mock keychain 测试：

```swift
func testMigrationMovesTokenToKeychain() throws {
    let defaults = UserDefaults(suiteName: "migration-test")!
    defaults.removePersistentDomain(forName: "migration-test")
    defaults.set("my-secret", forKey: "auth_token")
    defaults.set(0, forKey: "migration_version")

    let mock = MockKeychainService()
    let migrator = StorageMigrationManager(defaults: defaults, keychain: mock)
    try migrator.migrateIfNeeded()

    // 令牌移动到 keychain，从 UserDefaults 移除
    XCTAssertEqual(String(data: mock.storage["auth_token"]!, encoding: .utf8), "my-secret")
    XCTAssertNil(defaults.string(forKey: "auth_token"))
}
```

### 性能测试

```swift
func testKeychainWritePerformance() {
    let keychain = KeychainService(service: "com.test.perf")
    let options = XCTMeasureOptions()
    options.iterationCount = 20

    measure(metrics: [XCTClockMetric(), XCTCPUMetric()], options: options) {
        let data = UUID().uuidString.data(using: .utf8)!
        try? keychain.save(data, forKey: "perf-key")
        try? keychain.delete(forKey: "perf-key")
    }
}
```

### 变异测试

变异测试引入故意 bug（翻转 `==` 为 `!=`、移除 `SecItemDelete` 调用、交换 `&&` 为 `||`）并检查测试是否捕获它们。项目可能有 81% 代码覆盖率但仅 16% 变异分数——测试执行安全代码而不验证它做正确的事。

**Muter**（`brew install muter-mutation-testing/muter/muter`）是主要 Swift 变异测试工具。其 `RelationalOperatorReplacement` 操作符捕获认证绕过；`RemoveSideEffects` 捕获登出流程中缺失的 `SecItemDelete` 调用。对于安全代码，目标变异分数高于 **80%**。

### OWASP MASTG Keychain 验证

MASTG-TEST-0052 要求敏感数据使用 Keychain，而非 `NSUserDefaults` 或 `.plist` 文件。OWASP 还文档记录 keychain 数据在 App 卸载后持久——App 沙箱被清除但 keychain 条目保留。标准缓解是全新安装检测器（见 `common-anti-patterns.md`）：

```swift
static func handleFreshInstall(keychain: KeychainServiceProtocol) {
    let hasLaunched = UserDefaults.standard.bool(forKey: "has_launched")
    if !hasLaunched {
        try? keychain.deleteAll()
        UserDefaults.standard.set(true, forKey: "has_launched")
    }
}
```

---

## 结论

协议抽象对可测试 keychain 代码不可协商。每个 `SecItem` 调用都应在 `KeychainServiceProtocol` 后，使 95%+ 的测试套件针对 `MockKeychainService` 运行，零权限要求和零 CI 不稳定性。将真实 keychain 集成测试保留给物理设备上的专用测试计划。

大多数指南遗漏的三个洞察：(1) 模拟器静默返回生物识别保护条目而不提示——测试似乎验证生物识别门但什么也没测试；(2) TN3137 对基于文件和数据保护 keychain 的区分意味着 CI 中的 `security create-keychain` 创建错误 keychain 类型；(3) 变异测试揭示即使是高覆盖率套件也无法捕获反转条件和移除副作用——正是创造真实漏洞的变异。

---

## 总结清单

1. **协议抽象** —— 所有 keychain 访问通过 `KeychainServiceProtocol`；业务逻辑中无直接 `SecItem*` 调用
2. **带可注入错误的 mock** —— `MockKeychainService` 支持 `errorToThrow` 用于测试 `errSecDuplicateItem`、`errSecAuthFailed`、`errSecInteractionNotAllowed` 和 `errSecItemNotFound` 路径
3. **setUp/tearDown 清理** —— 使用真实 keychain 的每个集成测试都有带测试特定 `kSecAttrService` 的测试前和测试后清理
4. **Secure Enclave 保护** —— 所有 SE 测试使用 `try XCTSkipUnless(SecureEnclave.isAvailable, ...)` 或基于协议的回退；永不无条件调用 `SecureEnclave.P256.*`
5. **生物识别 mock** —— `LAContext` 包装在协议后或子类 mock；测试覆盖成功、用户取消、锁定和未注册场景
6. **模拟器/设备分离** —— 两个 Xcode 测试计划：`CITests`（基于 mock，模拟器安全）和 `DeviceTests`（物理设备上真实 keychain、SE、生物识别）
7. **CI keychain 设置** —— GitHub Actions 在证书导入后调用 `security set-key-partition-list`；测试目标有启用 Keychain Sharing 能力的宿主 App
8. **CryptoKit 往返** —— AES-GCM、ChaChaPoly、P256、Curve25519 的加密→解密和签名→验证测试；包含错误密钥失败测试
9. **错误路径覆盖** —— App 可以遇到的每个 `OSStatus` 代码都有带注入 mock 失败的对应测试
10. **迁移测试** —— UserDefaults→Keychain 迁移用隔离 `UserDefaults(suiteName:)` 和 mock keychain 测试；验证迁移后源清除
11. **变异测试基线** —— 安全关键代码路径的 Muter 变异分数 ≥80%；启用 `RelationalOperatorReplacement` 和 `RemoveSideEffects` 操作符
