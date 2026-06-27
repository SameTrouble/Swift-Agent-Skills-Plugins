# CryptoKit 公钥密码学

> **范围：** ECDSA 签名、ECDH 密钥协商、HPKE (iOS 17+)、ML-KEM/ML-DSA 和混合迁移模式 (iOS 26+)、密钥序列化和 Apple 平台上的 Secure Enclave 集成边界。
>
> **交叉引用：** Secure Enclave 密钥生命周期 → `secure-enclave.md`。密钥协商后的对称加密 → `cryptokit-symmetric.md`。CryptoKit 密钥的 Keychain 存储 → `credential-storage-patterns.md`。RSA → ECC 迁移 → 见下文 § "停止在新的 Apple 开发中使用 RSA"。

CryptoKit 的非对称密码学 API 涵盖 ECDSA 签名、ECDH 密钥协商、HPKE (iOS 17+) 和后量子 ML-KEM/ML-DSA (iOS 26+)。框架通过其类型系统强制正确使用——签名密钥不能执行密钥协商，共享密钥必须通过 HKDF 后才能使用，Secure Enclave 访问仅限于经典曲线的 P256。本参考涵盖从 iOS 13 到 iOS 26 的每个非对称原语，带经过验证的 Swift 实现、常见 AI 生成器错误和量子迁移路径。

CryptoKit 在 WWDC 2019（session 709，"Cryptography and Your Apps"）作为 Security framework 基于 C 的 `SecKey` API 的 Swift 原生替代品引入。它用每个微架构手调的汇编包装 Apple 的 corecrypto 库，同时提供性能和内存安全——私钥材料在解除分配时自动清零。iOS 14 添加了 PEM/DER 互操作和独立 HKDF。iOS 17 带来了 HPKE (RFC 9180)。iOS 26（WWDC 2025，session 314，"Get ahead with quantum-secure cryptography"）通过形式化验证的后量子算法和默认启用的量子安全 TLS 完善了图景。

---

## 曲线和算法选择指南

唯一最重要的决策是选择正确的曲线或算法。AI 生成器经常在需要 Secure Enclave 保护时推荐 Curve25519，或在现代常量时间性能更重要时默认使用 P-256。

### 经典曲线

**P256 (secp256r1 / NIST P-256)** —— Secure Enclave 支持的唯一经典曲线。需要硬件支持的密钥存储与生物识别访问控制。符合 NIST FIPS 186-5 用于美国政府合规，与 TLS、X.509 证书和服务端库有最广泛的互操作性。公钥 64 字节（未压缩原始），签名 64 字节（原始 r‖s）。iOS 14 起支持 PEM 和 DER 导出。

**Curve25519 (X25519 / Ed25519)** —— 应该是仅软件密钥的默认。其刚性参数设计消除了整类实现漏洞——常量时间执行是曲线算术固有的，无需点验证，公钥是紧凑的 32 字节。Ed25519 处理签名；X25519 处理密钥协商。权衡：仅 `rawRepresentation` 可用（无 PEM、无 DER、无 x963），无 Secure Enclave 支持。

**P384 和 P521** —— 为特定合规要求存在。P384 提供 ~192 位安全（NIST Category 3）；P521 提供 ~256 位安全（Category 5）。其 API 表面与 P256 完全相同。仅在规范或监管框架要求时使用。

### 后量子算法 (iOS 26+)

**ML-KEM-768 / ML-KEM-1024** —— FIPS 203 基于格的密钥封装。ML-KEM-768 目标 ~AES-128 等效安全；ML-KEM-1024 目标 ~AES-192。两者在 iOS 26+ 上支持 Secure Enclave 硬件隔离。

**ML-DSA-65 / ML-DSA-87** —— FIPS 204 基于格的数字签名。ML-DSA-65 目标 ~AES-128 等效；ML-DSA-87 目标 ~AES-192。两者在 iOS 26+ 上支持 Secure Enclave。

**X-Wing (XWingMLKEM768X25519)** —— 混合 KEM，结合 ML-KEM-768 和 X25519。两个算法都必须被破解才能入侵交换。这是 Apple 推荐的通过 HPKE 进行自定义协议的迁移路径。

### 选择决策矩阵

| 场景                      | iOS 版本 | 默认选择                                             | 理由                                    |
| ------------------------- | -------- | ---------------------------------------------------- | --------------------------------------- |
| 硬件隔离密钥              | 所有     | `SecureEnclave.P256.*`                               | 私钥永不离开协处理器                    |
| 软件签名/协商             | 所有     | `Curve25519.*`                                       | 常量时间，紧凑，现代协议                |
| FIPS/企业互操作           | 17+      | `P256` 或 `P384`                                     | 与遗留标准对齐                          |
| E2E 加密（现代）          | 17+      | 带 `Curve25519_SHA256_ChachaPoly` 的 HPKE            | 高性能，广泛客户端支持                  |
| E2E 加密（未来证明）      | 26+      | 带 `XWingMLKEM768X25519_SHA256_AES_GCM_256` 的 HPKE  | 针对现在收集以后解密的混合 PQC          |
| 最大经典安全              | 所有     | `P521`                                               | ~256 位安全；仅在强制要求时             |

### 算法快速参考

| 算法         | 安全性   | iOS | Secure Enclave | 公钥大小    | 最适合                        |
| ------------ | -------- | --- | -------------- | ----------- | ----------------------------- |
| P256         | ~128 位  | 13+ | ✅ 是          | 64 字节     | 硬件密钥，NIST 合规           |
| P384         | ~192 位  | 13+ | ❌ 否          | 96 字节     | 政府/合规                     |
| P521         | ~256 位  | 13+ | ❌ 否          | 132 字节    | 最大经典安全                  |
| Curve25519   | ~128 位  | 13+ | ❌ 否          | 32 字节     | 现代协议，软件密钥            |
| ML-KEM-768   | ~AES-128 | 26+ | ✅ 是          | 1,184 字节  | 密钥封装                      |
| ML-KEM-1024  | ~AES-192 | 26+ | ✅ 是          | 1,568 字节  | 更高安全 KEM                  |
| ML-DSA-65    | ~AES-128 | 26+ | ✅ 是          | 1,952 字节  | 后量子签名                    |
| ML-DSA-87    | ~AES-192 | 26+ | ✅ 是          | 2,592 字节  | 更高安全签名                  |
| X-Wing       | 混合     | 26+ | ✅ 是          | 1,216 字节  | 混合 PQC KEM                  |

在 Apple Silicon 上，P256 和 Curve25519 都在 corecrypto 中用手调汇编进行了重度优化。性能差异对大多数应用可以忽略——Apple 的 NISTZ256 优化缩小了 Curve25519 在非 Apple 基准测试中保持的差距。

---

## 签名和密钥协商是独立的类型层次结构

CryptoKit 最重要的设计决策是将每条曲线拆分为两个不可互换的类型族：`Signing` 和 `KeyAgreement`。`P256.Signing.PrivateKey` 不能执行密钥协商。`Curve25519.KeyAgreement.PrivateKey` 不能签名。编译器在构建时强制执行此。AI 生成器经常混淆这些，产生无法编译的代码。

### ✅ 正确：P256 密钥生成、签名和验证

```swift
import CryptoKit

// 生成签名密钥对
let signingKey = P256.Signing.PrivateKey()
let verifyingKey = signingKey.publicKey  // P256.Signing.PublicKey

// 签名数据（CryptoKit 内部用 SHA-256 哈希）
let message = Data("Transfer $100 to Alice".utf8)
let signature = try signingKey.signature(for: message)
// signature 是 P256.Signing.ECDSASignature

// 验证
let isValid = verifyingKey.isValidSignature(signature, for: message)

// 签名序列化
let derSig = signature.derRepresentation    // ASN.1 DER（可互操作）
let rawSig = signature.rawRepresentation    // 原始 r‖s 连接（64 字节）
let restored = try P256.Signing.ECDSASignature(derRepresentation: derSig)
```

对于预哈希数据（当摘要在外部计算时），使用带 `Digest` 参数或直接 `SHA256Digest` 的 `signature(for:)`。

### ❌ 错误：混用签名和密钥协商密钥类型

```swift
// 这不会编译——签名密钥不能做密钥协商
let key = P256.Signing.PrivateKey()
let shared = try key.sharedSecretFromKeyAgreement(with: otherPublicKey)
// 错误：P256.Signing.PrivateKey 没有成员 'sharedSecretFromKeyAgreement'

// 同样，Curve25519.KeyAgreement.PrivateKey 没有 .signature(for:) 方法
```

---

## 带 HKDF 派生的密钥协商

ECDH 产生的 `SharedSecret` 分布不均匀，永不能直接用作加密密钥。CryptoKit 强制执行此——`SharedSecret` 不能直接转换为 `SymmetricKey`。唯一批准的路径是 `.hkdfDerivedSymmetricKey()` 或 `.x963DerivedSymmetricKey()`。Apple 文档明确："共享密钥本身不适合作为对称加密密钥。"

### ✅ 正确：带 HKDF 派生的 Curve25519 密钥协商

```swift
import CryptoKit

// 双方生成密钥协商密钥（非签名密钥）
let aliceKey = Curve25519.KeyAgreement.PrivateKey()
let bobKey = Curve25519.KeyAgreement.PrivateKey()

// Alice 使用 Bob 的公钥计算共享密钥
let sharedSecret = try aliceKey.sharedSecretFromKeyAgreement(
    with: bobKey.publicKey
)

// 关键：通过 HKDF 派生对称密钥——永不直接使用 SharedSecret
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data("my-app-salt".utf8),
    sharedInfo: Data("encryption-v1".utf8),
    outputByteCount: 32  // 用于 AES-256 或 ChaChaPoly 的 256 位密钥
)

// 现在使用派生密钥进行认证加密
let sealed = try ChaChaPoly.seal(plaintext, using: symmetricKey)
```

`sharedInfo` 参数用作协议绑定——它确保为同一应用内不同目的派生的密钥不会被混淆。派生多个子密钥时，为加密密钥 vs 认证密钥使用不同的 `sharedInfo` 值。

### ❌ 错误：直接使用 SharedSecret 作为加密密钥

```swift
// 永不这样做——SharedSecret 分布不均匀
let sharedSecret = try aliceKey.sharedSecretFromKeyAgreement(with: bobPublicKey)

// SharedSecret 不是 SymmetricKey，不能直接用作对称密钥。
// 其字节分布不均匀（2^256 中仅 ~2^255 个值是
// 有效的 P-256 x 坐标）。跳过 HKDF 还会阻止协议绑定
// 并移除盐的熵集中益处。

// 这种强制提取是危险的：
let insecureKey = SymmetricKey(data: sharedSecret.withUnsafeBytes { Data($0) })
// ⚠️ 非均匀密钥材料，无域分离，无盐
```

---

## HPKE 简化公钥加密 (iOS 17+)

iOS 17 之前，为接收者公钥加密数据需要手动实现 ECIES：执行 ECDH，通过 HKDF 派生密钥，用 AES-GCM 加密，并将临时公钥与密文一起传输。HPKE (RFC 9180) 将整个流程打包到单个 API 中。CryptoKit 支持所有四种 RFC 模式——Base、Auth、PSK 和 AuthPSK——带五个内置密码套件。

### 内置密码套件

| 密码套件                                              | KEM           | KDF         | AEAD              | 最低 iOS |
| ----------------------------------------------------- | ------------- | ----------- | ----------------- | -------- |
| `.Curve25519_SHA256_ChachaPoly`                       | X25519        | HKDF-SHA256 | ChaCha20-Poly1305 | 17+      |
| `.P256_SHA256_AES_GCM_256`                            | P-256         | HKDF-SHA256 | AES-GCM-256       | 17+      |
| `.P384_SHA384_AES_GCM_256`                            | P-384         | HKDF-SHA384 | AES-GCM-256       | 17+      |
| `.P521_SHA512_AES_GCM_256`                            | P-521         | HKDF-SHA512 | AES-GCM-256       | 17+      |
| `.XWingMLKEM768X25519_SHA256_AES_GCM_256`             | X-Wing 混合   | HKDF-SHA256 | AES-GCM-256       | 26+      |

可构造自定义套件：`HPKE.Ciphersuite(kem: .P521_HKDF_SHA512, kdf: .HKDF_SHA512, aead: .AES_GCM_256)`。

### ✅ 正确：HPKE 加密和解密

```swift
import CryptoKit

let ciphersuite = HPKE.Ciphersuite.Curve25519_SHA256_ChachaPoly
let info = Data("MyApp-FileEncryption-v1".utf8)

// 接收者生成密钥对并共享公钥
let recipientPrivateKey = Curve25519.KeyAgreement.PrivateKey()
let recipientPublicKey = recipientPrivateKey.publicKey

// === 发送者 ===
// 需要 'var' —— seal() 变更内部 nonce 状态
var sender = try HPKE.Sender(
    recipientKey: recipientPublicKey,
    ciphersuite: ciphersuite,
    info: info
)
let ciphertext = try sender.seal(
    Data("Confidential document".utf8),
    authenticating: Data("metadata".utf8)  // 可选 AAD
)
let encapsulatedKey = sender.encapsulatedKey  // 必须与密文一起发送

// === 接收者 ===
var recipient = try HPKE.Recipient(
    privateKey: recipientPrivateKey,
    ciphersuite: ciphersuite,
    info: info,
    encapsulatedKey: encapsulatedKey  // 来自发送者
)
let plaintext = try recipient.open(
    ciphertext,
    authenticating: Data("metadata".utf8)  // 相同 AAD
)
```

### AI 生成器搞错的三个关键 HPKE 细节

1. **封装密钥未嵌入密文中。** 你的协议必须将 `encapsulatedKey` 与密文一起传输。丢失它意味着永久解密失败。

2. **`HPKE.Sender` 和 `HPKE.Recipient` 是必须用 `var` 声明的有状态结构体**，因为 `seal()` 和 `open()` 是变更方法——它们递增内部 nonce 计数器。使用 `let` 会导致编译器错误。

3. **消息顺序重要。** 如果发送者先密封消息 A 再密封 B，接收者必须先打开 A 再打开 B。内部计数器必须保持同步。

> **来源差异（已标记）：** 并行研究来源显示 `seal()` 返回带 `.encapsulatedKey` 和 `.ciphertext` 属性的结构体。Claude 来源显示 `encapsulatedKey` 作为 `HPKE.Sender` 的属性，`seal()` 返回 `Data`。根据 Apple 文档，`encapsulatedKey` 是 `HPKE.Sender` 的属性，`seal(_:authenticating:)` 返回 `Data`。Claude 来源正确。

---

## 后量子密码学 (iOS 26+)

在 WWDC 2025（session 314，"Get ahead with quantum-secure cryptography"），Apple 宣布 CryptoKit 支持 NIST 的后量子标准。威胁模型是"现在收集，以后解密"——对手今天存储加密流量以便在密码学相关量子计算机存在后解密。iOS 26 为 `URLSession` 和 `Network.framework` 默认启用量子安全 TLS，在 TLS ClientHello 中广播 `X25519MLKEM768`。

五个新类型加入 CryptoKit，全部由形式化验证实现支持，证明与 FIPS 规范功能等效：

| 类型                  | 算法           | 标准                          | 操作          | Secure Enclave | 密钥/签名大小                     |
| --------------------- | -------------- | ----------------------------- | ------------- | -------------- | -------------------------------- |
| `MLKEM768`            | ML-KEM-768     | FIPS 203                      | 密钥封装      | ✅             | 1,184 B 公 / 1,088 B 密文         |
| `MLKEM1024`           | ML-KEM-1024    | FIPS 203                      | 密钥封装      | ✅             | 1,568 B 公                        |
| `XWingMLKEM768X25519` | X-Wing 混合    | draft-connolly-cfrg-xwing-kem | 密钥封装      | ✅             | 1,216 B 公 / 1,120 B 封装         |
| `MLDSA65`             | ML-DSA-65      | FIPS 204                      | 数字签名      | ✅             | 1,952 B 公 / 3,309 B 签名         |
| `MLDSA87`             | ML-DSA-87      | FIPS 204                      | 数字签名      | ✅             | 2,592 B 公 / 4,627 B 签名         |

量子抵抗的大小成本是可观的——ML-DSA-65 签名是 3,309 字节 vs Ed25519 的 64 字节；ML-KEM-768 公钥是 1,184 字节 vs X25519 的 32 字节。但计算性能与经典算法相当。

### ✅ 正确：ML-KEM-768 密钥封装

密钥封装与 Diffie-Hellman 密钥协商家本上不同。在 ECDH 中，双方贡献公钥。在 KEM 中，只有接收者有密钥对——发送者在公钥上调用 `encapsulate()`，产生共享密钥和只有私钥才能解封装的不透明密文。

```swift
import CryptoKit

if #available(iOS 26, macOS 26, *) {
    // 接收者生成密钥对
    let privateKey = try MLKEM768.PrivateKey()
    let publicKey = privateKey.publicKey

    // 发送者封装（只需接收者公钥）
    let encapsulation = try publicKey.encapsulate()
    let senderSharedSecret = encapsulation.sharedSecret     // 32 字节
    let encapsulatedCiphertext = encapsulation.encapsulated  // 1,088 字节

    // 接收者解封装
    let recipientSharedSecret = try privateKey.decapsulate(encapsulatedCiphertext)

    // senderSharedSecret == recipientSharedSecret
    // 像使用 ECDH 一样通过 HKDF 派生对称密钥
}
```

### ✅ 正确：ML-DSA-65 签名

```swift
if #available(iOS 26, macOS 26, *) {
    let signingKey = try MLDSA65.PrivateKey()
    let verifyingKey = signingKey.publicKey  // 1,952 字节

    let message = Data("Authenticate this payload".utf8)
    let signature = try signingKey.signature(for: message)  // 3,309 字节

    let isValid = verifyingKey.isValidSignature(
        signature: signature,
        for: message
    )
}
```

### ✅ 正确：带 HPKE 的混合后量子（推荐迁移路径）

Apple 推荐的自定义协议方法是将 HPKE 密码套件切换到 X-Wing，它结合 ML-KEM-768 和 X25519，使两个算法都必须被破解才能入侵交换：

```swift
if #available(iOS 26, macOS 26, *) {
    // 量子安全 HPKE
    let ciphersuite = HPKE.Ciphersuite.XWingMLKEM768X25519_SHA256_AES_GCM_256
    let privateKey = try XWingMLKEM768X25519.PrivateKey()

    var sender = try HPKE.Sender(
        recipientKey: privateKey.publicKey,  // 1,216 字节
        ciphersuite: ciphersuite,
        info: Data("quantum-secure-v1".utf8)
    )
    let ciphertext = try sender.seal(sensitiveData)
    // encapsulatedKey 是 1,120 字节（vs 经典 X25519 的 ~32 字节）
}
```

### ✅ 正确：过渡期的混合签名（ML-DSA + ECDSA）

对于签名，Apple 在应用层演示了混合签名——连接 ML-DSA 和 ECDSA 签名并验证两者：

```swift
if #available(iOS 26, macOS 26, *) {
    let pqKey = try MLDSA65.PrivateKey()
    let ecKey = P256.Signing.PrivateKey()

    let pqSig = try pqKey.signature(for: message)
    let ecSig = try ecKey.signature(for: message).rawRepresentation
    let hybridSignature = pqSig + ecSig  // 连接两者

    // 验证两者——任一失败则拒绝
    let pqValid = pqKey.publicKey.isValidSignature(signature: pqSig, for: message)
    let ecValid = ecKey.publicKey.isValidSignature(
        try P256.Signing.ECDSASignature(rawRepresentation: ecSig), for: message
    )
    let isValid = pqValid && ecValid
}
```

---

## PEM 和 DER 互操作 (iOS 14+)

CryptoKit 的 PEM 支持对私钥使用 PKCS#8（`-----BEGIN PRIVATE KEY-----`），对公钥使用 X.509 SubjectPublicKeyInfo（`-----BEGIN PUBLIC KEY-----`）。导入也接受 SEC 1 格式（`-----BEGIN EC PRIVATE KEY-----`）。这实现了与 OpenSSL、BoringSSL 和服务端 TLS 库的互操作。

### ✅ 正确：PEM 密钥导出和导入

```swift
// 生成和导出
let privateKey = P256.Signing.PrivateKey()
let privatePEM = privateKey.pemRepresentation   // PKCS#8 PEM 字符串
let publicPEM = privateKey.publicKey.pemRepresentation  // X.509 SPKI PEM 字符串
let publicDER = privateKey.publicKey.derRepresentation  // 二进制 DER Data

// 从 PEM 导入（适用于 P256、P384、P521——不适用于 Curve25519）
let imported = try P256.Signing.PrivateKey(pemRepresentation: privatePEM)
let importedPub = try P256.Signing.PublicKey(derRepresentation: publicDER)
```

### 密钥格式参考

| 算法              | 公钥格式                  | 私钥格式                     | 备注                       |
| ----------------- | ------------------------- | ---------------------------- | -------------------------- |
| P-256 / P-384 / P-521 | SPKI DER/PEM、x963、原始  | PKCS#8 DER/PEM、x963、原始   | iOS 14+ 起完全互操作       |
| Curve25519        | 仅原始 32 字节            | 仅原始 32 字节               | 无 PEM/DER/x963 支持       |
| Secure Enclave P256 | 标准 SPKI DER/PEM        | 加密 blob（设备绑定）        | 公钥正常导出               |
| ML-KEM / ML-DSA   | 原始表示                  | 原始表示                     | iOS 26+                    |

**Curve25519 密钥不支持 PEM/DER。** 它们只有 `rawRepresentation`（公钥和私钥都是 32 字节）。如果需要与外部系统交换 Curve25519 密钥，自己处理原始字节序列化或用自定义格式包装原始字节。

### CryptoKit 密钥的 Keychain 存储

NIST 曲线密钥（P-256/P-384/P-521）可以通过 `SecKey` 桥接的 `SecKeyCreateWithData` 用 `kSecAttrKeyTypeECSECPrimeRandom` 存储为 `kSecClassKey` 条目。**非 NIST 密钥**（Curve25519、SymmetricKey）没有 `SecKey` 等效，必须作为 **`kSecClassGenericPassword`** 条目存储，原始密钥数据放在 `kSecValueData` 中。Secure Enclave 密钥（`SecureEnclave.P256.Signing.PrivateKey`）导出只有原始 SE 可以恢复的加密 blob——此 blob 也存储为通用密码，而非密钥条目。

**对等方/接收者公钥**从服务器或对等方接收（用于 ECDH、HPKE 或签名验证）也必须持久化在 keychain 中——永不在 UserDefaults、普通文件或源码中硬编码。对于 NIST 曲线，存储为 `kSecClassKey` 带 `kSecAttrKeyClass: kSecAttrKeyClassPublic`。对于 Curve25519 和后量子公钥，将 `rawRepresentation` 存储为 `kSecClassGenericPassword` 条目。使用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 作为可访问性，并分配不同的 `kSecAttrApplicationTag` 或 `kSecAttrAccount` 值（如 `"peer-"` 前缀）以将接收的对等方密钥与你自己的密钥对分开。见 `credential-storage-patterns.md` 了解 add-or-update 模式。

---

## Secure Enclave 集成（简要——见 `secure-enclave.md`）

Secure Enclave 在其硬件边界内生成、存储和操作私钥——原始密钥材料永不进入应用内存。

```swift
guard SecureEnclave.isAvailable else { return }

let accessControl = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryCurrentSet,
    nil
)!

// 带生物识别保护的签名密钥
let seKey = try SecureEnclave.P256.Signing.PrivateKey(
    accessControl: accessControl
)
let signature = try seKey.signature(for: data)

// 公钥是标准 P256.Signing.PublicKey——正常导出
let publicPEM = seKey.publicKey.pemRepresentation
```

对于经典曲线，只有 P256 与 Secure Enclave 一起工作。在 iOS 26 上，Secure Enclave 获得对 `SecureEnclave.MLKEM768`、`SecureEnclave.MLKEM1024`、`SecureEnclave.MLDSA65` 和 `SecureEnclave.MLDSA87` 的支持。

**关键生命周期约束：** Secure Enclave 密钥不可导出且加密绑定到特定设备和 OS 安装。`dataRepresentation` 是只有原始 SE 可以解密的加密 blob。iCloud 备份恢复到新设备后，SE 密钥不可恢复。应用必须实现密钥轮换和恢复机制——见 `secure-enclave.md` 了解完整生命周期模式。

---

## 停止在新的 Apple 开发中使用 RSA

CryptoKit 完全不包含 RSA。RSA 需要下降到 Security framework 基于 C 的 `SecKey` API，它缺乏类型安全、自动内存管理和现代 Swift 人体工程学。

### ❌ 错误：当 EC 可用时使用 RSA

```swift
// 新代码不要这样做——Security framework RSA
let params: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
    kSecAttrKeySizeInBits as String: 2048
]
var error: Unmanaged<CFError>?
let key = SecKeyCreateRandomKey(params as CFDictionary, &error)
// 无类型安全，手动内存管理，256 字节密钥，无 Secure Enclave
```

### 首选替代：CryptoKit 中的 P256 签名

```swift
// ✅ 对于新的 Apple 平台代码正确
let signingKey = P256.Signing.PrivateKey()
let message = Data("message".utf8)
let signature = try signingKey.signature(for: message)
let isValid = signingKey.publicKey.isValidSignature(signature, for: message)
```

> **来源差异（已标记）：** 并行研究来源显示 `Insecure.RSA.PrivateKey(keySize: .bits2048)` 作为反模式示例。此 API 在 CryptoKit 中不存在——没有 `Insecure.RSA` 类型。RSA 仅通过 Security framework 的 `SecKeyCreateRandomKey` 与 `kSecAttrKeyTypeRSA` 可用。Claude 来源的 Security framework 示例是正确的 API。

RSA-2048 用 256 字节密钥和签名仅提供 ~112 位安全。P256 用 32 字节私钥和 64 字节签名实现 ~128 位安全——签名大小减少 8 倍且安全性更强。仍然使用 RSA 的有效理由：遗留服务器互操作、CA 强制要求 RSA 的 X.509 证书，以及锁定到 RS256 的 JWT 规范。

---

## 常见 AI 生成器错误

| 反模式                                       | 风险                                           | 修复                                                                    |
| -------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------------------------- |
| 直接使用 `SharedSecret` 作为加密密钥          | 非均匀密钥材料；无域分离                        | 始终通过 `hkdfDerivedSymmetricKey()` 派生带盐和 sharedInfo              |
| 混用 `Signing` 和 `KeyAgreement` 密钥类型     | 编译错误；概念误用                              | 为每个操作使用正确类型层次结构                                          |
| 协议中缺少 HPKE `encapsulatedKey`            | 密文永久不可解密                                | 将 `encapsulatedKey` 与密文一起序列化和传输                             |
| 用 `let` 声明 `HPKE.Sender`/`Recipient`       | 编译错误（`seal()`/`open()` 是变更的）          | 用 `var` 声明                                                           |
| 新 iOS 代码使用 RSA                          | 更慢，更大密钥，无 CryptoKit/SE 支持            | 默认使用 ECC（P-256 或 Curve25519）                                     |
| 为 Secure Enclave 推荐 Curve25519            | Curve25519 无 SE 支持                           | 硬件支持密钥使用 `SecureEnclave.P256`                                   |
| 忽略 Curve25519 的 PEM/DER 格式限制          | 访问 `.pemRepresentation` 时运行时崩溃          | Curve25519 使用 `.rawRepresentation`；仅 NIST 曲线使用 PEM/DER          |
| 乱序使用 HPKE 消息                           | 解密失败（nonce 计数器不匹配）                  | 按密封顺序打开消息                                                      |

---

## iOS 版本要求

| 功能                                                | 最低 iOS | 关键备注                      |
| --------------------------------------------------- | -------- | ----------------------------- |
| CryptoKit 核心 (P256、P384、P521、Curve25519、SE P256) | 13.0+    | 所有经典曲线                  |
| PEM/DER 导入/导出、独立 HKDF                        | 14.0+    | 仅 NIST 曲线                  |
| HPKE (RFC 9180，所有四种模式)                       | 17.0+    | 所有密钥协商类型              |
| ML-KEM、ML-DSA、X-Wing、量子安全 TLS                | 26.0+    | 后量子类型，SE 支持           |

始终用 `#available` 检查门控后量子代码和 HPKE：

```swift
if #available(iOS 26, macOS 26, *) {
    // 后量子代码路径
} else if #available(iOS 17, macOS 14, *) {
    // 经典 HPKE 代码路径
} else {
    // 手动 ECIES 回退
}
```

---

## 性能和线程安全

CryptoKit 操作是 CPU 密集的，可从任何线程安全调用——框架不使用内部锁或共享可变状态。然而，密钥生成（特别是带生物识别门的 Secure Enclave 密钥）可能因用户交互而阻塞。永不在 `@MainActor` 上运行 SE 密钥操作。使用专用 actor 或 `Task.detached` 进行可能触发生物识别提示的密钥生成和签名。

对于批量操作，P256 签名和验证受益于 Apple Silicon 的硬件加密加速。Curve25519 操作在非 Apple 平台上的原始计算基准测试中略快，但 Apple 的 NISTZ256 优化使 A 系列和 M 系列芯片上的差异可以忽略。

后量子操作根据 Apple 的 WWDC 2025 演示在计算上与经典算法相当，但产生显著更大的输出。规划 3,309 字节 ML-DSA 签名和 1,184 字节 ML-KEM 公钥的带宽和存储影响。

---

## WWDC 会议和文档参考

- **WWDC 2019，Session 709** —— "Cryptography and Your Apps"——CryptoKit 介绍、曲线选择、密钥管理
- **WWDC 2020** —— "What's New in CryptoKit"——PEM/DER 支持、HKDF 独立 API
- **WWDC 2025，Session 314** —— "Get ahead with quantum-secure cryptography"——ML-KEM、ML-DSA、X-Wing、形式化验证实现、量子安全 TLS
- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit/)
- [SharedSecret Documentation](https://developer.apple.com/documentation/cryptokit/sharedsecret) —— HKDF 派生要求
- [HPKE Documentation](https://developer.apple.com/documentation/cryptokit/hpke) —— Sender/Recipient API
- [Storing CryptoKit Keys in the Keychain](https://developer.apple.com/documentation/CryptoKit/storing-cryptokit-keys-in-the-keychain) —— GenericPasswordConvertible 模式
- [Protecting Keys with the Secure Enclave](https://developer.apple.com/documentation/security/protecting-keys-with-the-secure-enclave)
- [Quantum-Secure Cryptography in Apple Operating Systems](https://support.apple.com/guide/security/quantum-secure-cryptography-apple-devices-secc7c82e533/web)

---

## 结论

CryptoKit 的类型系统是其最大特性——它在编译时防止了困扰手写实现的最危险加密错误。框架从 iOS 13 的四个曲线族发展到 iOS 26 的完整量子安全工具包，iOS 17 的 HPKE 作为关键桥梁。

对于今天的新开发：软件密钥默认使用 Curve25519，Secure Enclave 密钥使用 P256。使用 HPKE 而非手动 ECIES 进行公钥加密。始终通过带协议特定 `sharedInfo` 的 HKDF 从 `SharedSecret` 派生对称密钥。后量子迁移故意简单——将 HPKE 密码套件切换到 `XWingMLKEM768X25519_SHA256_AES_GCM_256` 并更改密钥类型。现在开始盘点自定义协议：现在收集以后解密的窗口已经打开。

---

## 总结清单

1. **曲线选择匹配要求** —— Secure Enclave / NIST 合规使用 P256；仅软件现代协议使用 Curve25519；仅在规范强制时使用 P384/P521
1. **签名和密钥协商使用正确类型族** —— 签名用 `*.Signing.PrivateKey`，ECDH 用 `*.KeyAgreement.PrivateKey`；永不尝试交叉使用
1. **SharedSecret 始终通过 HKDF 派生** —— 调用 `hkdfDerivedSymmetricKey(using:salt:sharedInfo:outputByteCount:)` 带协议特定 `sharedInfo`；永不使用原始共享密钥字节作为密钥
1. **HPKE 封装密钥与密文一起传输** —— `sender.encapsulatedKey` 未嵌入密文；协议必须序列化两者
1. **HPKE Sender/Recipient 用 `var` 声明** —— `seal()` 和 `open()` 是变更方法；`let` 会导致编译器错误
1. **HPKE 消息按密封顺序打开** —— 内部 nonce 计数器必须在发送者和接收者之间保持同步
1. **PEM/DER 仅用于 NIST 曲线** —— Curve25519 仅支持 `rawRepresentation`；尝试 PEM/DER 访问会失败
1. **新代码避免 RSA** —— 使用 CryptoKit ECC；RSA 仅用于通过 Security framework `SecKey` API 的遗留互操作
1. **后量子代码用 `#available(iOS 26, *)` 门控** —— ML-KEM、ML-DSA、X-Wing 需要 iOS 26+；HPKE 需要 iOS 17+
1. **Secure Enclave 密钥生命周期考虑设备迁移** —— SE 密钥设备绑定；为备份恢复场景实现轮换/恢复
1. **规划混合 PQC 策略** —— 密钥交换用 X-Wing HPKE，过渡期签名用 ML-DSA + ECDSA 双签名
1. **对等方/接收者公钥存储在 keychain** —— 用于 ECDH、HPKE 或验证的接收公钥持久化在 keychain 中带 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 和不同标签；不在 UserDefaults 或文件中
