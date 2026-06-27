# CryptoKit 对称密码学

> **范围：** SHA-2/SHA-3 哈希、HMAC 认证、AES-GCM 和 ChaChaPoly 认证加密、SymmetricKey 管理、nonce 处理、密钥派生（HKDF + PBKDF2）和 CommonCrypto 迁移。iOS 13+ 基线；SHA-3 需要 iOS 18+。
>
> **关键 API：** `SHA256`、`SHA384`、`SHA512`、`SHA3_256` (iOS 18+)、`HMAC`、`AES.GCM.seal/open`、`ChaChaPoly.seal/open`、`SymmetricKey`、`AES.GCM.Nonce`、`HKDF`、`SealedBox`
>
> **交叉引用：** [secure-enclave.md] 了解硬件支持的非对称密钥 · [cryptokit-public-key.md] 了解 ECDSA/ECDH/HPKE · [credential-storage-patterns.md] 了解 Keychain 中的密钥存储 · [common-anti-patterns.md] 了解包括硬编码密钥和 nonce 重用在内的前 5 个 AI 错误

---

## 哈希：SHA-2 和 SHA-3

CryptoKit 的哈希函数遵循统一的 `HashFunction` 协议。SHA-2 系列（`SHA256`、`SHA384`、`SHA512`）随 iOS 13+ 提供。SHA-3 系列（`SHA3_256`、`SHA3_384`、`SHA3_512`）需要 **iOS 18+ / macOS 15+ / tvOS 18+ / visionOS 2+**（2024 年添加，根据 Apple 的 SHA3_256 文档页面）。

> **交叉验证说明：** 一个研究来源声称 SHA-3 需要 iOS 26+。这不正确。Apple 官方文档列出 SHA3_256 可用性为 iOS 18.0+、macOS 15.0+。iOS 26 引入了后量子原语（ML-KEM、ML-DSA），而非 SHA-3。

所有哈希函数产生符合 `Sequence`（`UInt8`）、`ContiguousBytes`、`Hashable` 和 `CustomStringConvertible` 的摘要类型。摘要相等性检查内部使用**常量时间比较**以防止时序侧信道。

### 一次性哈希

**✅ 正确：带十六进制输出的 SHA-256 哈希**

```swift
import CryptoKit

let data = "Hello, CryptoKit".data(using: .utf8)!
let digest = SHA256.hash(data: data)

// 转换为十六进制字符串——Digest 符合 Sequence
let hexString = digest.map { String(format: "%02x", $0) }.joined()

// 常量时间比较
let otherDigest = SHA256.hash(data: data)
if digest == otherDigest {
    print("Integrity verified")
}
```

永不要依赖 `.description` 进行十六进制输出——Apple 警告其格式可能在 OS 版本间变化。

### 大文件的流式哈希

**✅ 正确：增量哈希以避免将整个文件加载到内存**

```swift
var hasher = SHA256()
let fileHandle = try FileHandle(forReadingFrom: fileURL)
while autoreleasepool(invoking: {
    let chunk = fileHandle.readData(ofLength: 1_048_576) // 1 MB 块
    guard !chunk.isEmpty else { return false }
    hasher.update(data: chunk)
    return true
}) {}
let digest = hasher.finalize()
```

所有哈希函数支持 `init()` → `update(data:)` → `finalize()`。`autoreleasepool` 包装器防止块读取期间的内存累积。

### 带可用性检查的 SHA-3

**✅ 正确：带回退的 SHA-3 (iOS 18+)**

```swift
func computeHash(data: Data) -> String {
    if #available(iOS 18.0, macOS 15.0, *) {
        let digest = SHA3_256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    } else {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

SHA-3 使用与 SHA-2（Merkle-Damgård）完全不同的内部构造（Keccak 海绵）。API 表面相同——只有类型名称变化。当合规标准要求或为防御未来 SHA-2 结构弱点而进行深度防御时采用 SHA-3。

### 不安全的哈希函数

**❌ 错误：将 MD5 或 SHA-1 用于任何安全目的**

```swift
// 永不——MD5 碰撞抗性 ~2^18 操作（商用硬件上秒级）
let broken = Insecure.MD5.hash(data: data)

// SHA-1 在 2020 年屈服于选择前缀碰撞（~$45,000 GPU 时间）
let alsoBroken = Insecure.SHA1.hash(data: data)
```

CryptoKit 特意将两者放在 `Insecure` 命名空间中作为 API 级别警告。所有安全目的使用 `SHA256` 最低——它在现代硬件上同样快并提供实际碰撞抗性。

**算法选择快速参考：**

| 算法     | 类型            | 可用性     | 状态       | 何时使用                                   |
| -------- | --------------- | ---------- | ---------- | ------------------------------------------ |
| SHA-256  | `SHA256`        | iOS 13+    | 强         | 完整性、签名、HMAC 的默认                  |
| SHA-384  | `SHA384`        | iOS 13+    | 强         | 证书链，更高安全边际                       |
| SHA-512  | `SHA512`        | iOS 13+    | 强         | 大数据，64 位上的性能                      |
| SHA3-256 | `SHA3_256`      | iOS 18+    | 强         | 要求 SHA-3 的合规                          |
| SHA3-384 | `SHA3_384`      | iOS 18+    | 强         | 未来证明                                   |
| SHA3-512 | `SHA3_512`      | iOS 18+    | 强         | 高安全上下文                               |
| MD5      | `Insecure.MD5`  | iOS 13+    | **已破损**| 仅遗留非安全校验和                         |
| SHA-1    | `Insecure.SHA1` | iOS 13+    | **已破损**| 仅遗留非安全校验和                         |

---

## HMAC：带对称密钥的消息认证

HMAC 将哈希函数与密钥结合产生认证码。CryptoKit 的 `HMAC<H>` 对任何 `HashFunction` 泛型，提供常量时间验证，并支持一次性 和流式模式。

**✅ 正确：HMAC 生成和验证**

```swift
import CryptoKit

let key = SymmetricKey(size: .bits256)
let message = "Transfer $500 to account 12345".data(using: .utf8)!

// 生成认证码
let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)

// 验证——常量时间比较防止时序攻击
let isValid = HMAC<SHA256>.isValidAuthenticationCode(
    mac, authenticating: message, using: key
)

// 序列化 MAC 用于传输
let macData = Data(mac)
```

**关键：** 始终使用 `isValidAuthenticationCode(_:authenticating:using:)` 进行验证——永不手动用 `==` 比较原始字节。CryptoKit 的方法内部使用 `safeCompare`，无论匹配多少字节都常量时间运行，击败时序侧信道攻击。

返回类型 `HMAC<SHA256>.MAC`（`HashedAuthenticationCode<SHA256>` 的别名）符合 `ContiguousBytes`、`Sequence`、`Hashable` 和 `CustomStringConvertible`。

**常见 HMAC 用例：** API 请求签名、webhook 载荷验证、传输中的数据完整性、基于令牌的认证方案。HMAC 证明真实性和完整性——不保密。对于加密，使用下面的 AES-GCM 或 ChaChaPoly。

---

## AES-GCM：一次操作的认证加密

AES-GCM 是 CryptoKit 的主要对称密码，提供**带关联数据的认证加密 (AEAD)**——保密性、完整性和真实性在单个 `seal()` 调用中。这消除了历史上危险的 AES-CBC + HMAC 手动组合模式。

### 基本加密和解密

**✅ 正确：带自动 nonce 的 AES-GCM 加密**

```swift
import CryptoKit

let key = SymmetricKey(size: .bits256)
let plaintext = "Sensitive data".data(using: .utf8)!

// 加密——CryptoKit 自动生成随机 12 字节 nonce
let sealedBox = try AES.GCM.seal(plaintext, using: key)

// 序列化用于存储/传输：nonce(12) ‖ 密文 ‖ 标签(16)
guard let combined = sealedBox.combined else {
    fatalError("Combined representation unavailable (non-standard nonce size)")
}

// 反序列化和解密
let restoredBox = try AES.GCM.SealedBox(combined: combined)
let decrypted = try AES.GCM.open(restoredBox, using: key)
```

`SealedBox` 包含三个组件：**12 字节 nonce**、**密文**（与明文相同长度）和 **16 字节认证标签**。`combined` 属性是 `Data?`（可选），因为非标准 nonce 大小阻止组合表示。对于 ChaChaPoly，`combined` 是非可选的。

### 关联数据 (AAD)

**✅ 正确：用关联数据将密文绑定到上下文**

```swift
let metadata = "user:42,action:payment".data(using: .utf8)!
let sealedBox = try AES.GCM.seal(plaintext, using: key, authenticating: metadata)

// 解密需要相同 AAD——篡改的元数据导致 authenticationFailure
let decrypted = try AES.GCM.open(sealedBox, using: key, authenticating: metadata)
```

关联数据被认证但**不加密**。用它将密文绑定到上下文（用户 ID、时间戳、资源标识符），使加密数据无法在不被检测的情况下移植到不同上下文。

### Nonce 重用的灾难性危险

**❌ 关键：永不重用 nonce 与相同密钥**

```swift
// 灾难性——启用完全密钥恢复
let staticNonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 12))
let box1 = try AES.GCM.seal(message1, using: key, nonce: staticNonce)
let box2 = try AES.GCM.seal(message2, using: key, nonce: staticNonce)
// 有 C1 和 C2，攻击者计算：C1 ⊕ C2 = P1 ⊕ P2
```

AES-GCM 中的 nonce 重用不是"坏实践"——它是称为"禁止攻击"（Joux，2006）的**完全加密破解**：

1. **明文恢复：** 相同 nonce + 密钥产生相同密钥流。异或两个密文得到 `P1 ⊕ P2`。如果任一明文已知或可猜，另一个立即恢复。
2. **认证伪造：** GCM 的认证使用 GHASH，GF(2^128) 上的多项式，带秘密哈希密钥 `H = AES_k(0^128)`。共享 nonce 的两条消息产生可通过 Cantor-Zassenhaus 求根解的多项式方程以恢复 H。一旦 H 已知，攻击者可以**为任意消息伪造有效认证标签**。

USENIX WOOT'16 研究发现 184 个 HTTPS 服务器在生产中重用 AES-GCM nonce，包括金融机构。

**修复：** 完全省略 `nonce:` 参数。CryptoKit 自动生成加密随机 12 字节 nonce，在相同密钥下 2^32 次加密后碰撞概率低于 2^-32。仅在互操作指定 nonce 值的外部系统时提供显式 nonce。

---

## ChaChaPoly：软件友好的 AEAD 替代

ChaCha20-Poly1305 提供等效的 AEAD 安全性和相同的 API 表面。它主要为**仅软件环境**存在，在这些环境中它提供常量时间执行而无需硬件加速，消除困扰软件 AES 实现的缓存时序侧信道。

**✅ 正确：ChaChaPoly 加密**

```swift
let key = SymmetricKey(size: .bits256)
let sealedBox = try ChaChaPoly.seal(plaintext, using: key)

// ChaChaPoly.SealedBox.combined 是非可选的（不同于 AES.GCM）
let combined = sealedBox.combined

// 解密
let restoredBox = try ChaChaPoly.SealedBox(combined: combined)
let decrypted = try ChaChaPoly.open(restoredBox, using: key)
```

API 与 AES-GCM 完全镜像——相同的 `seal`/`open` 方法，相同的 `SealedBox` 结构。在密码间切换只需更改类型名称。

### 性能：Apple 硬件上的 AES-GCM vs ChaChaPoly

在所有 Apple Silicon（A7 起的 A 系列，所有 M 系列）上，由于专用硬件 AES 指令，**AES-GCM 显著更快**：

| 指标               | AES-256-GCM                                                   | ChaChaPoly  | 来源                  |
| ------------------ | ------------------------------------------------------------- | ----------- | ----------------------- |
| 吞吐量 (M2 Pro)    | ~3–4 GB/s                                                     | ~1.5–2 GB/s | OpenSSL 基准测试       |
| 相对速度           | 快 134%–236%                                                  | 基线        | Ashvardanian (2025)    |
| Apple 内部使用     | Keychain 加密、文件数据保护、Watch↔iPhone 通信                 | —           | Platform Security Guide |

**在 Apple 硬件上默认使用 AES-GCM。** 在以下情况选择 ChaChaPoly：针对无硬件 AES 加速的平台、要求独立于硬件的保证常量时间行为，或互操作基于 ChaCha20 的协议（WireGuard、某些 TLS 配置）。

### 流式加密限制

`seal()` 和 `open()` 都不支持流式——两者都在内存中操作完整消息。对于大文件，实现**分块 AEAD 方案**，每个块有唯一 nonce，AAD 中有单调块索引以防止重排序攻击。或者，使用 Apple 的文件级数据保护（通过硬件加密引擎的 AES-XTS）进行静态文件加密。

---

## SymmetricKey：创建、派生和生命周期

`SymmetricKey` 是 CryptoKit 的不透明密钥容器。它在解除分配时**清零内存**（WWDC 2019-709 和 Apple 文档确认），防止意外暴露（无 `Data` 属性——仅 `withUnsafeBytes` 访问），并在构造时验证密钥大小。

### 随机密钥生成

**✅ 正确：加密随机密钥**

```swift
let key = SymmetricKey(size: .bits256) // 32 字节，加密随机
// 也可用：.bits128、.bits192
```

为量子弹性，优先使用 `.bits256`。Grover 算法将有效对称密钥强度减半——AES-256 对量子对手保持 128 位安全，而 AES-128 降至 64 位（不足）。

### 基于密码的密钥派生 (PBKDF2 + HKDF)

**❌ 错误：原始密码作为密钥材料**

```swift
// 永不——密码有 ~20-40 位熵，不是 256
let key = SymmetricKey(data: "MyPassword123".data(using: .utf8)!)
// 通过字典攻击可轻松暴力破解——无计算成本障碍，无盐
```

CryptoKit 提供 HKDF 但**不**提供 PBKDF2。对于基于密码的密钥派生，先使用 CommonCrypto 的 `CCKeyDerivationPBKDF`，然后可选 HKDF 进行子密钥派生：

**✅ 正确：通过 PBKDF2 + HKDF 的密码 → 密钥**

```swift
import CommonCrypto
import CryptoKit

// 步骤 1：PBKDF2 拉伸低熵密码
let password = "MyPassword123"
let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
var derivedBytes = [UInt8](repeating: 0, count: 32)

CCKeyDerivationPBKDF(
    CCPBKDFAlgorithm(kCCPBKDF2),
    password, password.utf8.count,
    Array(salt), salt.count,
    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
    600_000,  // OWASP 2023 推荐的 HMAC-SHA256 最低值
    &derivedBytes, derivedBytes.count
)

// 步骤 2：HKDF 派生目的特定子密钥（域分离）
let masterKey = SymmetricKey(data: derivedBytes)
let encryptionKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: masterKey,
    info: Data("encryption".utf8),
    outputByteCount: 32
)
let authKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: masterKey,
    info: Data("authentication".utf8),
    outputByteCount: 32
)
```

> **迭代计数说明：** 一个研究来源使用 100,000 次迭代。OWASP 2023 Password Storage Cheat Sheet 推荐_PBKDF2-HMAC-SHA256 最低 600,000 次迭代**。新实现使用 ≥600,000；仅在有文档化理由支持遗留互操作时使用较低计数。

**关键区别：** HKDF 为已经高熵的输入（共享密钥、主密钥）设计。它**不**增加计算成本。永不对密码单独使用 HKDF——始终先 PBKDF2。

### 高熵密钥派生的 HKDF

**✅ 正确：从高熵主密钥派生子密钥**

```swift
// 当输入已经高熵时（如 ECDH 共享密钥）
let inputKey = SymmetricKey(size: .bits256)
let derivedKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: inputKey,
    salt: Data("app-specific-salt".utf8),
    info: Data("aes-encryption-key-v1".utf8),
    outputByteCount: 32
)
```

HKDF 遵循 RFC 5869，支持一次性 `deriveKey()` 和两阶段 `extract()` → `expand()`。从单个共享密钥派生多个子密钥时，使用不同的 `info` 字符串进行域分离。iOS 14+ 起可用。

> **API 说明：** `HKDF.deriveKey()` 不抛出——尽管某些代码示例显示，不需要 `try`。

### 密钥存储和硬编码

**❌ 错误：源码中硬编码密钥**

```swift
// 永不——通过 `strings` 命令在二进制上可提取
let key = SymmetricKey(data: Data(base64Encoded: "c2VjcmV0S2V5MTIzNDU2Nzg5MDEyMzQ1Ng==")!)
```

Zimperium 2025 研究发现 48% 的移动 App 包含硬编码密钥。iOS 二进制可以用 Hopper 或 IDA Pro 等工具解密和分析。**将密钥存储在 Keychain** 中带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`，运行时从用户凭据派生，或从安全服务器获取。见 [credential-storage-patterns.md] 了解详细模式。

**SymmetricKey 内存行为：** 密钥存在于常规进程内存中（非 Secure Enclave——只有非对称 `SecureEnclave.P256` 密钥是硬件支持的）。CryptoKit 在解除分配期间自动覆盖密钥材料。对于持久存储，序列化到 Keychain——永不要 UserDefaults 或文件。

---

## 从 CommonCrypto 迁移到 CryptoKit

CommonCrypto 的 C API 需要手动缓冲区分配、不安全指针管理，不提供认证加密。CryptoKit 用类型安全的 Swift 替代所有常见操作，更难误用。

### 哈希：CC_SHA256 → SHA256

```swift
// ❌ 遗留 CommonCrypto——不安全指针，手动缓冲区大小
import CommonCrypto
var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
data.withUnsafeBytes { bytes in
    CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
}

// ✅ CryptoKit——一行，类型安全
import CryptoKit
let digest = SHA256.hash(data: data)
```

### 加密：CCCrypt (AES-CBC) → AES.GCM

```swift
// ❌ 遗留 CommonCrypto——AES-CBC，未认证，手动 IV，缓冲区数学
import CommonCrypto
var outputBuffer = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
var numBytesEncrypted = 0
let status = CCCrypt(
    CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
    CCOptions(kCCOptionPKCS7Padding),
    keyBytes, kCCKeySizeAES256, ivBytes,
    dataBytes, data.count,
    &outputBuffer, outputBuffer.count, &numBytesEncrypted
)
// ⚠️ 还需要单独添加 HMAC 用于完整性！

// ✅ CryptoKit——一行，认证，自动 nonce
import CryptoKit
let sealedBox = try AES.GCM.seal(data, using: key)
```

关键架构转变：CommonCrypto 的 `CCCrypt` 提供 AES-CBC（未认证）。没有手动 Encrypt-then-MAC (HMAC)，CBC 密文容易受**填充预言攻击**和静默篡改。CryptoKit 的 AES-GCM 打包认证——`open()` 在任何字节被修改时抛出 `CryptoKitError.authenticationFailure`。

### HMAC：CCHmac → HMAC

```swift
// ❌ 遗留 CommonCrypto——C 风格指针
import CommonCrypto
var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
       keyBytes, keyData.count, dataBytes, data.count, &hmac)

// ✅ CryptoKit——泛型，类型安全，内置常量时间验证
import CryptoKit
let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
let valid = HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: data, using: key)
```

### CommonCrypto 中保留什么

CryptoKit 特意省略：**PBKDF2**（使用 `CCKeyDerivationPBKDF`）、**AES-CBC**（遗留系统互操作所需）、**AES-ECB**（几乎从不合适）。对于其他一切，CryptoKit 是正确选择。

---

## AI 代码生成器错误

大型语言模型生成 iOS 加密代码时经常引入这些错误：

**1. 使用 CommonCrypto 而非 CryptoKit。** 在较旧代码上训练的模型默认使用 `CC_SHA256` 和 `CCCrypt`。这些需要手动内存管理且缺乏认证加密。iOS 13+ 目标始终使用 CryptoKit。

**2. 重用或硬编码 nonce。** 生成器有时创建一次 nonce 并重用，或使用 `Data(repeating: 0, count: 12)`。这启用完全 AES-GCM 密钥恢复（见上面的 nonce 重用章节）。省略 `nonce:` 参数以使用自动生成。

**3. 使用不带认证的 AES-CBC。** 生成器产生基于 `CCCrypt` 的 AES-CBC 而无 HMAC，使密文容易受填充预言攻击。AES-GCM 和 ChaChaPoly 默认认证——新代码中无理由使用未认证加密。

**4. 直接从密码字符串创建 SymmetricKey。** `SymmetricKey(data: password.data(using: .utf8)!)` 经常出现。这完全跳过密钥拉伸。密码使用 PBKDF2（≥600,000 次迭代），然后可选 HKDF 进行子密钥派生。

**5. 推荐 MD5 或 SHA-1 用于校验和。** 生成器建议 `Insecure.MD5` 用于文件完整性。SHA-256 在现代硬件上同样快且具有实际碰撞抗性。

**6. 手动 SealedBox 序列化。** 生成器有时手动连接 nonce + 密文 + 标签而非使用 `SealedBox.combined`。这引入序列化 bug——使用内置 `combined` 属性和 `SealedBox(combined:)` 初始化器。

---

## 对称密码学的量子考虑

WWDC 2025 session 314（"Get ahead with quantum-secure cryptography"）为非对称加密引入 ML-KEM 和 ML-DSA（见 [cryptokit-public-key.md]）。对于对称加密，量子计算机通过 Grover 算法将有效密钥强度大致减半：

- **AES-256：** 128 位后量子安全——**充足**
- **AES-128：** 64 位后量子安全——**不足**

**推荐：** 专门使用 `SymmetricKey(size: .bits256)`。iOS 26 中为 `URLSession` 和 Network.framework 连接默认启用量子安全 TLS 1.3。

CryptoKit 基于 Apple 的 **corecrypto** 库构建（FIPS 140-2/140-3 验证，每个 Apple 微架构手调汇编）。Apple 的硬件加密引擎位于闪存和系统内存之间的 DMA 路径中，以线速执行内联 AES-256 加密，零 CPU 开销。

---

## OWASP 映射

CryptoKit 对称实践解决 **OWASP Mobile Top 10 M10（加密不足）**：弱算法、密钥长度不足、密钥管理不当、实现缺陷。

**相关 MASTG 测试案例：** MASTG-TEST-0061（算法配置）、MASTG-TEST-0062（密钥管理）、MASTG-TEST-0209（密钥大小不足）、MASTG-TEST-0210（破损对称算法）、MASTG-TEST-0211（破损哈希）、MASTG-TEST-0213（硬编码密钥）、MASTG-TEST-0317（破损加密模式）。

**MASTG 知识库：** MASTG-KNOW-0066（CryptoKit）、MASTG-KNOW-0067（CommonCrypto）。

**MASWE 条目：** MASWE-0010（不当密钥派生）、MASWE-0013（硬编码加密密钥）、MASWE-0020（不当加密）、MASWE-0021（不当哈希）、MASWE-0022（可预测初始化向量）。

见 [compliance-owasp-mapping.md] 了解完整合规矩阵。

---

## 测试指导

| 测试案例                                  | 证明什么                 | 预期结果                       |
| ---------------------------------------- | ------------------------ | ------------------------------ |
| 密文篡改后 AES-GCM 解密                  | 认证工作                 | `CryptoKitError.authenticationFailure` |
| 错误 AAD 的 AES-GCM 解密                 | 元数据绑定               | `CryptoKitError.authenticationFailure` |
| 错误密钥的 HMAC 验证                     | 时序安全验证             | 返回 `false`                   |
| 篡改消息的 HMAC 验证                     | 完整性检测               | 返回 `false`                   |
| SHA-3 可用性回退                         | 向后兼容                 | <iOS 18 回退到 SHA-256         |
| SealedBox 往返（组合格式）               | 序列化正确性             | 解密输出匹配明文               |
| PBKDF2 + HKDF 派生确定性                 | 密钥派生可重现性         | 相同密码 + 盐 → 相同密钥       |

**CI 扫描规则：** 在代码审查中标记 `Insecure.MD5`、`Insecure.SHA1`、`CCCrypt`、`SymmetricKey(data:` 后跟字符串字面量和硬编码 base64 密钥模式。

---

## WWDC 和参考引用

- **WWDC 2019-709** —— "Cryptography and Your Apps"：CryptoKit 介绍、SymmetricKey 内存清零、自动 nonce 生成理由
- **WWDC 2020** —— "What's New in CryptoKit"：HKDF 添加 (iOS 14)、扩展密钥协商
- **WWDC 2025 Session 314** —— "Get ahead with quantum-secure cryptography"：AES-256 量子指导、SHA-3 上下文、ML-KEM/ML-DSA（非对称）
- **Apple CryptoKit Documentation** —— https://developer.apple.com/documentation/cryptokit/
- **Apple Platform Security Guide** —— corecrypto FIPS 验证、硬件加密引擎、文件数据保护
- **OWASP Mobile Top 10 (2024)** —— M10：加密不足
- **OWASP MASTG** —— iOS 加密测试方法论
- **RFC 5869** —— HKDF 规范
- **Joux (2006)** —— "Authentication Failures in NIST version of GCM"（nonce 重用攻击）

---

## 结论

CryptoKit 的设计哲学——默认认证加密、自动 nonce 生成、内存清零、常量时间比较——消除了最常见的加密实现错误类别。对于新代码：带自动 nonce 的 `AES.GCM.seal()` 用于加密，`SHA256`（或 iOS 18+ 上的 `SHA3_256`）用于哈希，`HMAC<SHA256>` 用于认证，`SymmetricKey(size: .bits256)` 用于密钥生成。通过 PBKDF2（≥600,000 次迭代，CommonCrypto）后接 HKDF（CryptoKit）从密码派生密钥——永不要将原始密码传递给 `SymmetricKey(data:)`。将密钥存储在 Keychain 中，而非源码。在 Apple 硬件上优先 AES-GCM 而非 ChaChaPoly 以获得硬件加速优势，但 ChaChaPoly 对于跨平台一致性或仅软件环境仍然可靠。

---

## 总结清单

1. **CryptoKit 优于 CommonCrypto** —— 所有新哈希、HMAC 和加密使用 `import CryptoKit`，而非 `import CommonCrypto`（PBKDF2 除外）
2. **最低 SHA-256** —— 任何安全目的不使用 `Insecure.MD5` 或 `Insecure.SHA1`；CI 规则标记这些
3. **AES-GCM 或 ChaChaPoly** —— 所有对称加密使用 AEAD；新代码中无未认证 AES-CBC
4. **自动 nonce** —— 除非协议强制，否则 `seal()` 调用中省略 `nonce:` 参数；无静态或零 nonce
5. **256 位密钥** —— `SymmetricKey(size: .bits256)` 用于量子弹性；安全敏感数据不使用 `.bits128`
6. **密码用 HKDF 前先 PBKDF2** —— 密码 → `CCKeyDerivationPBKDF`（≥600,000 次迭代，≥16 字节随机盐）→ `SymmetricKey` → 可选 HKDF 用于子密钥；永不原始密码到 `SymmetricKey(data:)`
7. **SealedBox.combined 用于序列化** —— 存储和网络使用 `.combined` / `SealedBox(combined:)`；无手动 nonce/密文/标签连接
8. **密钥在 Keychain** —— 对称密钥通过 Keychain 持久化带 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`；源码中无硬编码密钥，无 UserDefaults，无 plist
9. **常量时间 HMAC 验证** —— 使用 `HMAC.isValidAuthenticationCode()`，永不手动字节比较
10. **SHA-3 可用性保护** —— `SHA3_256` 包装在 `#available(iOS 18.0, macOS 15.0, *)` 中带 SHA-256 回退
11. **关联数据用于上下文绑定** —— 当密文必须绑定到元数据（用户 ID、资源 ID、版本）时使用 AES-GCM `authenticating:` 参数
