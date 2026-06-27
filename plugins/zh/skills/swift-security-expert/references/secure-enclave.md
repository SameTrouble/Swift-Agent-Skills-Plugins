# Secure Enclave：iOS 和 macOS 的硬件支持密钥操作

> 范围：Secure Enclave 的能力、约束和集成模式，用于 Apple 平台上的密钥生成、持久化、生物识别门控和可测试性。

**Secure Enclave (SE) 是 Apple 的专用安全协处理器——一个物理隔离的芯片，在硅片中生成、存储和操作加密密钥，永不将私钥材料暴露给应用处理器。** 自 iPhone 5s (2013) 起的每个现代 Apple 设备都包含此硬件，但开发者经常误用它，因为微妙的 API 行为、模拟器陷阱和 AI 代码生成器一致搞错的基本架构约束。本参考涵盖 CryptoKit 的 `SecureEnclave` 模块 (iOS 13+)、遗留 Security framework 路径、iOS 26 后量子添加、正确和错误的代码模式、持久化、测试策略和必须设计的硬件限制。

主要来源：Apple Platform Security Guide（Secure Enclave 章节）、CryptoKit `SecureEnclave` 类型的 Apple Developer Documentation、WWDC 2019 Session 709 "Cryptography and Your Apps"、WWDC 2025 "Get ahead with quantum-secure cryptography"、Apple DTS 文档 "Protecting keys with the Secure Enclave" 和 "Storing CryptoKit Keys in the Keychain"。

---

## Secure Enclave 实际是什么

SE 是嵌入 Apple SoC 的专用安全子系统，运行自己的微内核（sepOS——在专有 AKF ARMv7a 核心上 300–400 MHz 的定制 L4 微内核）。它有自己的 boot ROM（不可变，启动时加密验证）、硬件真随机数生成器 (TRNG)、AES 引擎、公钥加速器 (PKA) 和加密内存区域。与应用处理器的通信专门通过中断驱动的邮箱发生——硬件过滤器阻止所有其他访问路径。

SE 的核心保证：**在 Secure Enclave 内部生成的私钥材料永不离开其硬件边界。** 当你的代码"使用"SE 密钥时，它通过邮箱发送请求，SE 内部执行加密操作，仅结果（签名、共享密钥）返回。没有 API、调试接口或 JTAG 路径提取原始密钥。

每个 SoC 有在制造时永久熔合到硅片中的唯一 ID (UID)。此 UID 对任何软件（包括 Apple 的）不可访问，并作为所有 SE 密钥派生的根加密密钥。这就是使密钥不可撤销地设备绑定的原因。

**带 Secure Enclave 的设备：** 自 iPhone 5s 起的所有 iPhone（A7+ 芯片）、自 iPad Air 起的所有 iPad、Apple Watch Series 1+、自 Apple TV HD（第 4 代）起的所有 Apple TV、HomePod、所有带 T1/T2/M 系列芯片的 Mac 和 Apple Vision Pro。无 T1 或 T2 芯片的 Intel Mac（2016 前 MacBook Pro、2018 前 MacBook Air、2020 前 iMac 除外 iMac Pro）**没有** Secure Enclave。

---

## 必须设计的硬件限制

这些约束是架构性的，非 bug——它们是 SE 安全模型的基础：

- **经典 EC 仅 P-256** —— 无 P-384、P-521、Curve25519 或 secp256k1。CryptoKit 没有 `SecureEnclave.P384` 或 `SecureEnclave.Curve25519` 类型。iOS 26 添加基于格的后量子算法（ML-KEM、ML-DSA），非额外曲线。
- **无对称密钥操作** —— 内部 AES 引擎处理数据保护和 FileVault 但**不作为开发者 API 暴露**。没有 `SecureEnclave.AES`。
- **无密钥导出** —— `SecKeyCopyExternalRepresentation()` 对 SE 私钥失败。`dataRepresentation` 属性返回加密的不透明 blob，非原始密钥材料。
- **无密钥导入** —— 密钥必须在 SE 内部生成。`init(dataRepresentation:)` 仅接受来自先前创建的 SE 密钥的不透明 blob——非任意密钥材料。SE 密钥类型上没有 `init(rawRepresentation:)`。
- **设备绑定** —— 密钥绑定到制造时熔合的设备 UID。它们不在恢复出厂设置后存活，不能备份到 iCloud，不能通过 iCloud Keychain 同步，不能转移到替换设备。
- **存储有限** —— SE 有约 4 MB 闪存用于密钥。对典型 App（几十个密钥）不是问题，但以高量生成密钥时相关。
- **性能开销** —— 每次操作需要中断驱动的往返到隔离协处理器。SE 不适合高频操作（每秒数千次签名）。批量签名或批量加密应使用 SE 派生的对称密钥。

---

## CryptoKit SecureEnclave API (iOS 13+)

CryptoKit 的 `SecureEnclave` 模块是新代码的主要 API。它用 Swift 原生类型包装较低级别的 Security framework，提供编译时类型安全、解除分配时自动内存清零，以及使误用困难的精心策划的 API 表面。

支持两个操作族：**签名**（`SecureEnclave.P256.Signing`）和**密钥协商**（`SecureEnclave.P256.KeyAgreement`）。

### 创建签名密钥

```swift
// ✅ 正确：健壮的可用性检查 + 密钥创建
import CryptoKit

func createSigningKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
    #if targetEnvironment(simulator)
    throw SecureEnclaveError.notAvailable
    #else
    guard SecureEnclave.isAvailable else {
        throw SecureEnclaveError.notAvailable
    }
    return try SecureEnclave.P256.Signing.PrivateKey()
    #endif
}

enum SecureEnclaveError: Error {
    case notAvailable
    case keyCreationFailed(underlying: Error)
}
```

`#if targetEnvironment(simulator)` 编译时保护至关重要。**`SecureEnclave.isAvailable` 可能在 Simulator 上返回 `true`**，当宿主 Mac 有 SE 硬件（T2/M 系列）时，但实际密钥生成在运行时失败。此行为跨 Xcode 版本变化——一些一致返回 `false`，其他反映宿主硬件。编译时检查完全消除歧义。

> **交叉验证说明：** Claude 研究来源文档化模拟器 `isAvailable` 返回 `true` 作为确认陷阱；并行研究来源指出 `isAvailable` 在模拟器上始终为 `false`。真实世界行为取决于 Xcode 版本和宿主硬件。上面的防御性模式（编译时保护 + 运行时检查）无论你的环境表现哪种行为都正确。

```swift
// ❌ 不正确：无可用性检查——在模拟器和旧设备上崩溃
let key = try SecureEnclave.P256.Signing.PrivateKey()
// 模拟器：根据 Xcode 版本错误 -25293 或 EXC_BAD_ACCESS
```

### 签名和验证

一旦你有 SE 密钥，签名很简单。SE 内部执行 ECDSA 并返回标准 `P256.Signing.ECDSASignature`。验证使用公钥——一个可以自由导出并在任何地方使用的常规 `P256.Signing.PublicKey`：

```swift
// ✅ 用 SE 密钥签名，用公钥验证
let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
let message = "Transfer $500 to Alice".data(using: .utf8)!

// 签名在 Secure Enclave 硬件内发生
let signature = try privateKey.signature(for: message)

// 公钥是标准 P256——任何地方工作，导出为 DER 用于服务器
let publicKey = privateKey.publicKey
let isValid = publicKey.isValidSignature(signature, for: message) // true

let derSignature = signature.derRepresentation   // 用于线格式
let rawSignature = signature.rawRepresentation   // 用于紧凑存储
let publicDER = publicKey.derRepresentation       // 向后端注册
```

### 带 HKDF 派生的密钥协商 (ECDH)

`SecureEnclave.P256.KeyAgreement.PrivateKey` 在 SE 内部执行椭圆曲线 Diffie-Hellman。产生的 `SharedSecret` 然后通过 HKDF 派生为可用对称密钥——这是从 SE 密钥开始到对称加密的**唯一正确路径**：

```swift
// ✅ 正确：ECDH 密钥协商 → HKDF → AES-GCM
let localKey = try SecureEnclave.P256.KeyAgreement.PrivateKey()
let localPublicKey = localKey.publicKey // 发送给对等方

// 从对等方接收（从 DER 或原始字节解码）
let peerPublicKey: P256.KeyAgreement.PublicKey = // ...

// ECDH 在 Secure Enclave 内部发生
let sharedSecret = try localKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

// 使用 HKDF-SHA256 派生 256 位 AES 密钥
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: "com.myapp.v1.salt".data(using: .utf8)!,
    sharedInfo: "encryption-key".data(using: .utf8)!,
    outputByteCount: 32
)

// 现在使用派生的软件密钥进行 AES-GCM 加密
let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)
```

```swift
// ❌ 错误：没有 SE 对称 API
// SecureEnclave.AES.GCM.seal(data, using: seKey) — 不存在
// AES.GCM.seal(data, using: seSigningKey) — 类型不匹配（需要 SymmetricKey）
```

> ECDH + HKDF 模式在 `cryptokit-public-key.md` § 带 HKDF 派定的密钥协商中完整覆盖——包括曲线选择、`info` 参数指导和输出密钥长度。

---

## 通过 dataRepresentation 持久化 SE 密钥

CryptoKit SE 密钥默认是**临时的**——如果你不持久化 `dataRepresentation`，App 终止时密钥引用丢失。`dataRepresentation` 属性返回只有同一设备上同一 Secure Enclave 可以使用以重建密钥的不透明加密 blob。它明确**不是**原始私钥。

```swift
// ✅ 将 SE 密钥持久化到 keychain 并稍后检索
import CryptoKit
import Security

// --- 存储 ---
let privateKey = try SecureEnclave.P256.Signing.PrivateKey()
let keyBlob: Data = privateKey.dataRepresentation // 加密的，设备绑定

let storeQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "com.myapp.signing-key",
    kSecValueData as String: keyBlob,
    kSecAttrAccessible as String:
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
// Delete-then-add 模式以处理现有条目
SecItemDelete(storeQuery as CFDictionary)
let status = SecItemAdd(storeQuery as CFDictionary, nil)
guard status == errSecSuccess else {
    throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
}

// --- 检索 ---
let fetchQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "com.myapp.signing-key",
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]
var item: CFTypeRef?
let fetchStatus = SecItemCopyMatching(fetchQuery as CFDictionary, &item)
guard fetchStatus == errSecSuccess, let storedBlob = item as? Data else {
    throw NSError(domain: NSOSStatusErrorDomain, code: Int(fetchStatus))
}

let restoredKey = try SecureEnclave.P256.Signing.PrivateKey(
    dataRepresentation: storedBlob
)
// restoredKey 完全功能——操作路由到同一 SE 密钥
```

在 macOS 上，添加 `kSecUseDataProtectionKeychain: true` 以目标现代数据保护 keychain 而非遗留基于文件的 keychain。在 iOS/tvOS/watchOS 上此标志冗余但无害。

**始终使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`** 用于 SE 密钥 blob——密钥无论如何设备绑定，可同步可访问性级别会将 blob 存储在 iCloud 服务器上那里无用（可以解密它的 SE 不在那里）。

---

## 带 SecAccessControl 的生物识别门控 SE 密钥

最安全关键的 SE 模式结合硬件密钥隔离与生物识别认证。SE 内部评估访问控制策略，使其即使对 OS 级别入侵也防篡改。

```swift
// ✅ 完整的生物识别门控 SE 密钥创建 (iOS 13+)
import CryptoKit
import LocalAuthentication
import Security

func createBiometricKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
    guard SecureEnclave.isAvailable else {
        throw SecureEnclaveError.notAvailable
    }

    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet],
        &error
    ) else {
        throw error!.takeRetainedValue() as Error
    }

    let context = LAContext()
    context.localizedReason = "Authenticate to create signing key"
    context.touchIDAuthenticationAllowableReuseDuration = 10

    return try SecureEnclave.P256.Signing.PrivateKey(
        compactRepresentable: true,
        accessControl: accessControl,
        authenticationContext: context
    )
}

// 稍后：重建并使用（出现生物识别提示）
func signWithBiometricKey(storedBlob: Data, data: Data) throws -> Data {
    let context = LAContext()
    context.localizedReason = "Authenticate to sign transaction"

    let key = try SecureEnclave.P256.Signing.PrivateKey(
        dataRepresentation: storedBlob,
        authenticationContext: context
    )
    return try key.signature(for: data).derRepresentation
}
```

```swift
// ❌ 省略 .privateKeyUsage 导致签名失败
let badControl = SecAccessControlCreateWithFlags(
    nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryCurrentSet, // 缺少 .privateKeyUsage！
    nil
)!
// 密钥创建成功，但签名操作将失败
```

**访问控制标志选择：**

- **`.biometryCurrentSet`** —— 最强。用户重新注册生物识别时密钥永久失效（添加新指纹、重新注册 Face ID）。银行/医疗最佳。失效发生时需要 re-keying 逻辑。
- **`.biometryAny`** —— 密钥在生物识别重新注册后存活。大多数 App 的安全性和便利性良好平衡。
- **`.userPresence`** —— 接受生物识别或设备密码。最灵活；当你只需证明有人存在时使用。

**关键操作说明：** 如果你使用 `.biometryCurrentSet` 且用户更改已注册的生物识别，密钥变得**永久不可用**。你的 App 必须检测 `errSecItemNotFound` 或认证错误，向用户解释为何需要重新认证，并生成带服务端重新注册的新密钥。（见 `biometric-authentication.md` 了解完整 LAContext 集成模式。）

---

## 遗留 Security framework 方法 (iOS 10+)

CryptoKit 之前，SE 密钥通过带 `kSecAttrTokenIDSecureEnclave` 的 `SecKeyCreateRandomKey` 创建。这仍然工作，在针对 iOS 13 之前或处理基于证书的身份操作时必要：

```swift
// 遗留方法——功能正常但冗长；新代码优先 CryptoKit
import Security

func legacyCreateSEKey(tag: String) throws -> SecKey {
    let access = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet],
        nil
    )!

    let attributes: NSDictionary = [
        kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits: 256,
        kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
        kSecPrivateKeyAttrs: [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: tag.data(using: .utf8)!,
            kSecAttrAccessControl: access
        ]
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
        throw error!.takeRetainedValue() as Error
    }
    return privateKey
}
```

新代码优先 CryptoKit，因为它提供编译时类型安全（每个算法/操作不同类型）、自动内存清零、Swift 原生错误处理和精心策划的 API 表面。Security framework 对证书管理（`SecTrust`）、RSA 密钥或通过较旧 API 存储的现有 keychain 条目仍然必要。（见 `certificate-trust.md` 了解 SecTrust 模式。）

---

## iOS 26：Secure Enclave 中的后量子密码学

WWDC 2025 session "Get ahead with quantum-secure cryptography" 宣布了自 2013 年引入以来 SE 开发者面向能力的最重要扩展。从 **iOS 26、macOS 26 和所有 2025 平台发布**开始，四个新算法系列可用：

- **`SecureEnclave.MLKEM768`** 和 **`SecureEnclave.MLKEM1024`** —— 后量子密钥封装 (FIPS 203)。用于量子抗性密钥交换的硬件隔离 ML-KEM 操作。
- **`SecureEnclave.MLDSA65`** 和 **`SecureEnclave.MLDSA87`** —— 后量子数字签名 (FIPS 204)。抗量子攻击的硬件隔离 ML-DSA 签名。

这些是**硬件支持**的，非仅软件。Apple 明确确认 SE 支持。实现形式化验证为与 FIPS 规范功能等效。

**默认量子安全 TLS：** `URLSession` 和 `Network.framework` 在 iOS 26 中自动升级到使用 X-Wing (ML-KEM768 + X25519) 的量子安全 TLS 1.3。包括 CloudKit、推送通知和 Private Relay 在内的系统服务已经使用它。对大多数开发者，无需代码更改。

**自定义端到端加密：** Apple 推荐结合后量子和经典算法的混合构造。`XWingMLKEM768X25519` 类型提供混合 KEM 密码套件。对于应用级加密，使用 `SecureEnclave.MLKEM768.PrivateKey` 在硬件边界内封装/解封装共享密钥。

**API 演进时间线：**

| 发布                 | SE 开发者添加                                                                                  |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| **iOS 13** (2019)    | CryptoKit 引入：`SecureEnclave.P256.Signing`、`.P256.KeyAgreement`、`.isAvailable`             |
| **iOS 14** (2020)    | 无 SE 变化。添加 HKDF、PEM/DER 格式支持                                                       |
| **iOS 15–16** (2021–22) | 无 SE 变化                                                                                     |
| **iOS 17** (2023)    | 无 SE 变化。添加 HPKE（仅软件）。iMessage PQ3 在 17.4 发布                                     |
| **iOS 18** (2024)    | 无 SE 变化                                                                                     |
| **iOS 26** (2025)    | **重大扩展**：`.MLKEM768`、`.MLKEM1024`、`.MLDSA65`、`.MLDSA87`。默认量子安全 TLS              |

SE 的经典椭圆曲线支持保持**仅 P-256**——扩展完全进入基于格的后量子算法。

> 完整后量子算法目录——包括仅软件类型、X-Wing 混合 KEM 构造、密钥/签名大小权衡、HPKE 集成模式和混合经典+PQ 签名——见 `cryptokit-public-key.md` § 后量子密码学 (iOS 26+)。此章节专门涵盖硬件支持的 SE 变体。

---

## 何时使用 SE vs 软件密钥

**使用 Secure Enclave 用于：** 根签名密钥、设备认证、交易授权、生物识别门控认证，以及任何需要证明在特定物理设备上持有密钥的场景。不可导出保证是核心价值——入侵应用处理器的攻击者仍无法提取私钥。

**使用标准 keychain（软件密钥）用于：** 会话令牌、API 密钥、对称加密密钥、需要 P-256 之外算法的密钥（RSA、P-384、Ed25519）、必须通过 iCloud Keychain 同步的密钥、需要在设备更换后存活的密钥，以及需要每秒数千次操作的高吞吐量操作。

**常见有效模式：** 在 SE 中存储主非对称密钥并使用 ECDH 派生或包装对称密钥用于批量加密。SE 保护信任根；派生密钥处理高吞吐量工作。

反模式是对每个密钥都伸手 SE。P-256 约束、性能开销和设备绑定意味着 SE 密钥应保护最关键的操作，而非替代标准 keychain。（见 `credential-storage-patterns.md` 了解令牌生命周期模式。）

---

## AI 生成器搞错的六个正确性陷阱

这些模式在 LLM 生成代码中例行出现。每个都反映对 SE 硬件架构的误解。

### 1. 不检查 isAvailable（和模拟器双重陷阱）

最小检查是 `SecureEnclave.isAvailable`，但仅此在模拟器上不足。健壮模式结合编译时和运行时检查：

```swift
// ✅ 健壮的可用性检查——到处安全
var canUseSecureEnclave: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return SecureEnclave.isAvailable
    #endif
}
```

### 2. 尝试导入外部密钥

SE 密钥类型上没有 `init(rawRepresentation:)`。`init(dataRepresentation:)` 仅接受来自先前创建的 SE 密钥的不透明 blob：

```swift
// ❌ 不可能：无法将现有密钥导入 Secure Enclave
let externalKey = P256.Signing.PrivateKey()
let rawBytes = externalKey.rawRepresentation
// SecureEnclave.P256.Signing.PrivateKey(rawRepresentation:) 不存在
// SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: rawBytes) 将抛出

// ✅ 密钥必须在 SE 内部生成
let seKey = try SecureEnclave.P256.Signing.PrivateKey()
```

### 3. 尝试直接 AES/对称加密

SE 的内部 AES 引擎不向开发者暴露。使用 ECDH → HKDF → AES-GCM 替代（见上面的密钥协商章节）。

### 4. 假设 SE 密钥可以备份或转移

SE 密钥设备绑定。服务端架构**必须**注册设备公钥并支持用户更换设备时 re-keying。从第一天起设计重新注册流程。

### 5. CryptoKit 可用时使用遗留 Security framework

`SecKeyCreateRandomKey` + `kSecAttrTokenIDSecureEnclave` 仍然工作，但 CryptoKit 消除约 20 行基于字典的 C 风格代码并提供编译时类型安全。仅对 iOS 13 之前目标或证书操作使用遗留 API。

### 6. 访问控制中省略 .privateKeyUsage

带 `SecAccessControl` 创建用于生物识别门控的 SE 密钥**必须**包含 `.privateKeyUsage`。没有它，密钥创建成功但签名操作在某些配置上静默失败。始终组合：`[.privateKeyUsage, .biometryCurrentSet]`。

---

## 测试和 CI/CD 策略

### 用于可测试 SE 代码的基于协议的抽象

由于 SE 操作在模拟器和大多数 CI 环境上失败，将加密操作抽象在带 SE、软件和 mock 实现的协议后面：

```swift
// ✅ 用于可测试 SE 依赖代码的协议抽象
import CryptoKit
import Foundation

protocol SigningKeyProvider {
    var publicKeyData: Data { get throws }
    func sign(_ data: Data) throws -> Data
}

// 生产：Secure Enclave 实现
final class SESigningKey: SigningKeyProvider {
    private let key: SecureEnclave.P256.Signing.PrivateKey

    init() throws { self.key = try SecureEnclave.P256.Signing.PrivateKey() }
    init(dataRepresentation: Data) throws {
        self.key = try SecureEnclave.P256.Signing.PrivateKey(
            dataRepresentation: dataRepresentation)
    }

    var publicKeyData: Data { get throws { key.publicKey.derRepresentation } }
    func sign(_ data: Data) throws -> Data {
        try key.signature(for: data).derRepresentation
    }
}

// 回退：软件 P256（相同曲线，相同签名格式）
final class SoftwareSigningKey: SigningKeyProvider {
    private let key: P256.Signing.PrivateKey

    init() { self.key = P256.Signing.PrivateKey() }
    var publicKeyData: Data { get throws { key.publicKey.derRepresentation } }
    func sign(_ data: Data) throws -> Data {
        try key.signature(for: data).derRepresentation
    }
}

// 测试：Mock 实现
final class MockSigningKey: SigningKeyProvider {
    var publicKeyDataToReturn = Data()
    var signatureToReturn = Data()
    var shouldThrow = false
    var signCallCount = 0

    var publicKeyData: Data { get throws { publicKeyDataToReturn } }
    func sign(_ data: Data) throws -> Data {
        signCallCount += 1
        if shouldThrow { throw NSError(domain: "Mock", code: -1) }
        return signatureToReturn
    }
}
```

### 带 SE → 软件回退的工厂

```swift
// ✅ 运行时工厂——可用时 SE，否则软件
struct SigningKeyFactory {
    static func create() throws -> SigningKeyProvider {
        #if targetEnvironment(simulator)
        return SoftwareSigningKey()
        #else
        if SecureEnclave.isAvailable {
            return try SESigningKey()
        }
        return SoftwareSigningKey()
        #endif
    }
}
```

SE 和软件实现都产生**相同的 P256 ECDSA 签名**——验证代码无论哪个实现创建密钥都相同工作。

### XCTest 模式

```swift
import XCTest
@testable import MyApp

final class AuthServiceTests: XCTestCase {
    func testSignChallenge() throws {
        let mock = MockSigningKey()
        mock.signatureToReturn = Data([0xDE, 0xAD])
        let service = AuthService(signingKey: mock)

        let result = try service.signChallenge(Data("test".utf8))

        XCTAssertEqual(mock.signCallCount, 1)
        XCTAssertEqual(result, Data([0xDE, 0xAD]))
    }

    func testRealSEKey() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Secure Enclave not available on Simulator")
        #else
        guard SecureEnclave.isAvailable else {
            throw XCTSkip("Secure Enclave not available on this hardware")
        }
        let key = try SESigningKey()
        let signature = try key.sign(Data("test".utf8))
        XCTAssertFalse(signature.isEmpty)
        #endif
    }
}
```

### CI/CD 现实

GitHub Actions macOS 运行器（arm64 和 Intel）在 **Secure Enclave 不可访问**的 VM 中运行——Apple Virtualization Framework 不将 SE 访问传递给客户 VM。物理 Mac 硬件（Mac mini M 系列、带 T2 的 MacBook Pro）上的自托管运行器确实有 SE 访问。Xcode Cloud 在 Apple Silicon 上运行，但 SE 可用性取决于特定云配置。

**实用 CI 方法：** 在 CI 上用 mock 运行单元测试；仅在物理设备测试农场或自托管运行器上运行 SE 集成测试；用 `XCTSkip` 保护标记 SE 特定测试以条件执行。（见 `testing-security-code.md` 了解全面 CI/CD 模式。）

---

## 操作指导：轮换、迁移和事件响应

将 SE 密钥视为**临时的、设备绑定的制品**而非永久用户身份：

- **设备更换：** 当用户获得新设备时，旧设备的 SE 密钥消失。你的 App 必须检测缺失密钥（keychain blob 缺失或 `dataRepresentation` 重建失败）并触发重新注册流程：生成新 SE 密钥，向你的后端注册其公钥，并使旧公钥失效。
- **生物识别重新注册：** 如果使用 `.biometryCurrentSet`，添加新指纹或重置 Face ID 永久使密钥失效。捕获错误，向用户解释为何需要重新认证，并配置新密钥。
- **密钥轮换：** SE 密钥的定期轮换遵循相同重新注册模式。生成新密钥，向服务器注册新公钥，用旧密钥签名过渡令牌（如果仍有效），并从 keychain 删除旧密钥 blob。
- **事件响应：** 如果设备在 OS 级别被入侵，SE 密钥仍受保护（SE 独立操作）。然而，如果物理设备在攻击者手中且他们知道密码，他们可以向 SE 认证。通过 MDM 或查找我的远程擦除销毁 UID 派生的密钥层次，使所有 SE 密钥永久不可恢复。

---

## 结论

Secure Enclave 的开发者表面从 iOS 13 到 iOS 25 非常稳定——`SecureEnclave.P256` 是整个 API。iOS 26 用后量子 ML-KEM 和 ML-DSA 打开了边界，SE 12 年历史中的首次算法扩展。实践洞察是**正确的 SE 使用更多在于你不做什么**（不跳过可用性检查，不尝试导入密钥，不假设可移植性，不使用 SE 进行对称加密）而非复杂 API 编排。CryptoKit API 特意最小且难误用，这是其最大优势。

对于新项目，推荐架构是：围绕签名和密钥协商的基于协议的抽象；SE 实现为主带软件 P256 回退；`dataRepresentation` 持久化在 keychain 中作为 `kSecClassGenericPassword` 带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；高价值密钥的生物识别访问控制；服务端公钥注册带设备更换 re-keying 支持；以及物理硬件上带 `XCTSkip` 保护的集成测试。

---

## 总结清单

1. **可用性保护** —— 任何 SE 密钥创建前始终组合 `#if targetEnvironment(simulator)`（编译时）与 `SecureEnclave.isAvailable`（运行时）。永不假设 SE 存在。
2. **无密钥导入** —— SE 密钥必须在硬件内生成。`init(dataRepresentation:)` 仅重建现有 SE 密钥——它无法导入外部密钥材料。
3. **无对称加密** —— SE 不向开发者暴露 AES。从 SE 密钥开始的加密工作流使用 ECDH → HKDF → `AES.GCM`。
4. **设备绑定设计** —— SE 密钥无法备份、同步或转移。从第一天起为设备更换构建服务端重新注册流程。
5. **持久化 dataRepresentation** —— 将不透明加密 blob 存储在 keychain 中作为 `kSecClassGenericPassword` 带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`。无持久化，密钥在 App 终止时丢失。
6. **包含 .privateKeyUsage** —— 为生物识别门控 SE 密钥创建 `SecAccessControl` 时，始终在生物识别标志旁包含 `.privateKeyUsage`。省略它导致签名静默失败。
7. **处理生物识别失效** —— `.biometryCurrentSet` 密钥在生物识别重新注册时永久失效。检测错误并触发带服务端通知的 re-keying。
8. **协议抽象** —— 将 SE 操作抽象在带 SE、软件和 mock 实现的协议后面以实现可测试性。SE 和软件 P256 产生相同签名格式。
9. **CryptoKit 优于 Security framework** —— 新代码使用 `SecureEnclave.P256.Signing.PrivateKey` (CryptoKit) 而非 `SecKeyCreateRandomKey` + `kSecAttrTokenIDSecureEnclave`。Security framework 保留给证书和 iOS 13 之前目标。
10. **iOS 26 后量子** —— `SecureEnclave.MLKEM768/1024` 和 `.MLDSA65/87` 是硬件支持的。对于自定义 E2E 加密，采用混合构造（经典 + PQC）。`URLSession` TLS 自动升级。
11. **CI/CD 跳过保护** —— 在 CI 中为 SE 特定测试使用 `XCTSkip`。GitHub Actions VM 无 SE 访问。仅在物理硬件或设备农场上运行 SE 集成测试。
