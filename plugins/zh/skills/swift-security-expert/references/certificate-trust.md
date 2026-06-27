# 证书信任评估与锁定

> **范围**：SecCertificate、SecTrust 评估、SecIdentity、证书锁定策略（叶 / 中间 CA / SPKI 哈希 / NSPinnedDomains）、自定义信任策略、客户端证书认证 (mTLS)、ATS 交互和操作锁定管理。iOS 12+ 至 iOS 18，macOS 10.14+ 至 macOS 15。
>
> **不在范围内**：超出 TLS 证书处理的网络层加密、服务端证书管理、作为独立主题的 App Transport Security（仅在它与锁定相交处简要覆盖）。

---

## 核心安全类型

| 类型               | 用途                                               | 关键操作                                                                                                                  |
| ------------------ | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `SecCertificate`   | X.509 证书（DER 编码）                             | `SecCertificateCreateWithData`、`SecCertificateCopyKey` (iOS 12+)、`SecCertificateCopyData`、`SecCertificateCopySubjectSummary` |
| `SecTrust`         | 针对策略的证书链信任评估上下文                      | `SecTrustCreateWithCertificates`、`SecTrustEvaluateWithError` (iOS 12+)、`SecTrustEvaluateAsyncWithError` (iOS 13+)       |
| `SecIdentity`      | 用于客户端认证的私钥 + 证书对                       | 通过 `SecPKCS12Import` 提取；与 `URLCredential(identity:certificates:persistence:)` 一起使用                              |
| `SecPolicy`        | 验证策略（SSL 主机名检查、吊销）                    | `SecPolicyCreateSSL`、`SecPolicyCreateRevocation`                                                                         |

---

## 信任评估 API

存在三个信任评估函数。只有两个是当前的。

### SecTrustEvaluateAsyncWithError — 推荐的异步 API (iOS 13+)

```swift
func SecTrustEvaluateAsyncWithError(
    _ trust: SecTrust,
    _ queue: dispatch_queue_t,
    _ result: @escaping (SecTrust, Bool, CFError?) -> Void
) -> OSStatus
```

回调接收布尔结果和可选错误。如果信任对象有缓存结果，回调可能同步触发。始终在**后台队列**上分发——评估可能执行网络访问以获取中间证书或进行吊销检查。

```swift
// ✅ 正确：异步信任评估带正确错误处理
func evaluateTrust(_ trust: SecTrust, completion: @escaping (Bool, Error?) -> Void) {
    let queue = DispatchQueue.global(qos: .userInitiated)
    queue.async {
        let status = SecTrustEvaluateAsyncWithError(trust, queue) { _, result, error in
            completion(result, error as Error?)
        }
        if status != errSecSuccess {
            completion(false, NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
}
```

Apple **未**为 Security framework 添加原生 async/await 包装器直到 iOS 18。手动包装：

```swift
// ✅ 正确：Swift 并发包装器
func evaluateTrust(_ trust: SecTrust) async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async {
            let status = SecTrustEvaluateAsyncWithError(trust, queue) { _, result, error in
                if result {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: error! as Error)
                }
            }
            if status != errSecSuccess {
                continuation.resume(throwing: NSError(
                    domain: NSOSStatusErrorDomain, code: Int(status)))
            }
        }
    }
}
```

### SecTrustEvaluateWithError — 同步，仍为当前 (iOS 12+)

```swift
func SecTrustEvaluateWithError(_ trust: SecTrust, _ error: UnsafeMutablePointer<CFError?>?) -> Bool
```

**未废弃。** 在 `URLSessionDelegate` 回调中有效（已经离开主线程）。Apple 的警告：不要从主运行循环调用——它可能需要网络访问。

### SecTrustEvaluate — 自 iOS 13 起废弃

```swift
// ❌ 废弃：返回不透明的 SecTrustResultType 而无错误上下文
func SecTrustEvaluate(_ trust: SecTrust,
                      _ result: UnsafeMutablePointer<SecTrustResultType>) -> OSStatus
```

返回需要手动解释的 `SecTrustResultType` 枚举。被 `SecTrustEvaluateWithError` 替代。**AI 生成器经常产生此模式——看到就拒绝。**

### SecTrustResultType 参考

对于必须在评估后通过 `SecTrustGetTrustResult` 检查结果的代码：

| 结果                     | 含义                                  | 操作                            |
| ------------------------ | ------------------------------------- | ------------------------------- |
| `.unspecified`           | 链验证到隐式信任的锚                  | **继续**——最常见的成功         |
| `.proceed`               | 用户明确选择信任此证书                | **继续**                        |
| `.deny`                  | 用户明确标记证书为不可信              | **拒绝**——永不覆盖             |
| `.recoverableTrustFailure` | 失败但可恢复                         | 检查，可能重新配置              |
| `.fatalTrustFailure`     | 根本证书缺陷                          | **拒绝**                        |
| `.otherError`            | 非信任错误（吊销、OS 错误）           | **拒绝**                        |
| `.invalid`               | 尚未执行评估                          | 先调用评估                      |

现代 `SecTrustEvaluateWithError` 将此折叠为布尔。仅将 `.unspecified` 和 `.proceed` 视为成功。

---

## 自定义信任策略配置

```swift
// ✅ 正确：带主机名验证的 SSL 策略
let policy = SecPolicyCreateSSL(true, "api.example.com" as CFString)
// true = 服务器评估；主机名启用 SNI 匹配

var trust: SecTrust?
SecTrustCreateWithCertificates(certificateChain as CFTypeRef, policy, &trust)
```

```swift
// ✅ 正确：自定义锚同时保留系统信任存储
SecTrustSetAnchorCertificates(trust, [customRootCA] as CFArray)
SecTrustSetAnchorCertificatesOnly(trust, false)  // false = 也信任系统锚
```

```swift
// ❌ 不正确：缺少 SecTrustSetAnchorCertificatesOnly
SecTrustSetAnchorCertificates(trust, [customRootCA] as CFArray)
// 没有 SecTrustSetAnchorCertificatesOnly(trust, false)，所有系统锚
// 被静默禁用——只有你的自定义 CA 被信任！
```

```swift
// ❌ 不正确：nil 主机名完全禁用主机名验证
let policy = SecPolicyCreateSSL(true, nil)
// 任何域的任何有效证书现在都通过——MITM 向量
```

---

## 四种锁定策略

### 叶证书锁定 — 每次续订都失效

商业 TLS 证书每 90 天（Let's Encrypt）到 398 天（CA/Browser Forum 最大值）过期。当服务器续订时，证书字节改变（新序列号、有效期、签名），锁定失效。用户被锁定直到 App Store 更新发布。

```swift
// ❌ 危险：叶证书锁定在每次证书续订时失效
guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
      let serverCert = chain.first else {
    completionHandler(.cancelAuthenticationChallenge, nil)
    return
}
let serverCertData = SecCertificateCopyData(serverCert) as Data
let localCertData = // 从 bundle .cer 文件加载

if serverCertData == localCertData {
    completionHandler(.useCredential, URLCredential(trust: serverTrust))
} else {
    // 证书续订时会触发，锁定所有用户
    completionHandler(.cancelAuthenticationChallenge, nil)
}
```

**结论**：除非你控制完整证书生命周期且可以在不经过 App Store 审查的情况下更新锁定，否则生产中永不使用。

### 中间 CA 锁定 — 5–10 年有效期窗口

锁定中间 CA 证书。该 CA 签发的任何叶证书通过检查。服务器可以自由续订其叶证书。

```swift
// ✅ 正确：中间 CA 锁定（对叶证书续订有弹性）
guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
    completionHandler(.cancelAuthenticationChallenge, nil)
    return
}

let pinnedIntermediateData = // 从 bundle 加载中间 CA .cer

for cert in chain {
    let certData = SecCertificateCopyData(cert) as Data
    if certData == pinnedIntermediateData {
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
        return
    }
}
completionHandler(.cancelAuthenticationChallenge, nil)
```

**权衡**：信任该 CA 的任何证书，不仅仅是你的。如果 CA 被入侵，同 CA 证书可以冒充你的服务器。

### SPKI 哈希锁定 — 相同密钥对续订时存活

哈希 SubjectPublicKeyInfo (SPKI) 结构。当证书**用相同密钥对**续订时，SPKI 保持相同。这是**推荐的编程方法**。

**关键正确性问题**：`SecKeyCopyExternalRepresentation` 返回**不带** ASN.1 SPKI 头的原始密钥字节。你必须在哈希前预置正确的头。省略此步骤会产生无法匹配 OpenSSL 生成的锁定的错误哈希。

> ⚠️ **交叉验证说明**：并行研究来源省略了 ASN.1 头预置步骤并使用废弃的 `SecTrustGetCertificateAtIndex`。以下代码使用正确的现代 API 和正确的 SPKI 构造。

```swift
// ✅ 正确：带 ASN.1 头和现代 API 的 SPKI 哈希锁定
class SPKIPinningDelegate: NSObject, URLSessionDelegate {

    // 用于从原始密钥数据重建 SPKI 的 ASN.1 头
    private static let rsa2048Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]
    private static let ecP256Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ]

    private let pinnedHashes: Set<String>  // Base64(SHA256(SPKI))

    init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 步骤 1：始终先通过系统信任验证链
        guard SecTrustEvaluateWithError(serverTrust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 步骤 2：遍历链并检查 SPKI 哈希
        guard let chain = SecTrustCopyCertificateChain(serverTrust)
                as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for cert in chain {
            if let hash = spkiHash(for: cert), pinnedHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let attrs = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attrs[kSecAttrKeyType] as? String,
              let keySize = attrs[kSecAttrKeySizeInBits] as? Int else { return nil }

        let header: [UInt8]
        switch (keyType, keySize) {
        case (kSecAttrKeyTypeRSA as String, 2048): header = Self.rsa2048Header
        case (kSecAttrKeyTypeRSA as String, 4096):
            // 为生产使用添加 RSA-4096 头
            return nil
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 256):
            header = Self.ecP256Header
        default: return nil
        }

        var spki = Data(header)
        spki.append(keyData)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        spki.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(spki.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}
```

从命令行生成预期的 SPKI 哈希：

```bash
# 从 PEM 证书文件：
openssl x509 -in cert.pem -noout -pubkey | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | openssl enc -base64

# 从实时服务器：
openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | openssl enc -base64
```

### NSPinnedDomains — 声明式锁定，零代码 (iOS 14+)

Apple 推荐的方法。通过 ATS 由 `URLSession` 自动强制执行。使用 SPKI 哈希。

```xml
<!-- ✅ 正确：通过 NSPinnedDomains 进行 CA 身份锁定带备份锁定 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>api.example.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>PrimaryCA_SPKI_Hash_Base64==</string>
                </dict>
                <dict>
                    <!-- 来自不同提供商的备份 CA -->
                    <key>SPKI-SHA256-BASE64</key>
                    <string>BackupCA_SPKI_Hash_Base64==</string>
                </dict>
            </array>
        </dict>
    </dict>
</dict>
```

每个锁定域的可用键：

- **`NSPinnedCAIdentities`** —— 匹配链中的任何中间或根证书（数组内逻辑 OR）
- **`NSPinnedLeafIdentities`** —— 仅匹配叶证书
- **`NSIncludesSubdomains`** —— `true` 时覆盖一级子域

如果**同时**指定 `NSPinnedCAIdentities` 和 `NSPinnedLeafIdentities`，ATS 要求在**每个**类别中匹配（类别间 AND，每个类别内 OR）。

**限制**：与 `URLSession` 和 `WKWebView` 一起工作（iOS 16+ 在早期 bug 修复后）。不与 `SFSafariViewController` 一起工作。锁定在 `Info.plist` 中可见，无法在不更新 App 的情况下更新。

### 锁定策略决策矩阵

| 策略             | 弹性                              | 特异性                    | 更新频率            | 最适合                          |
| ---------------- | --------------------------------- | ------------------------- | ------------------- | ------------------------------- |
| 叶证书           | ❌ 每 90–398 天失效               | 最高——精确证书匹配        | 每次续订            | 生产中永不使用                  |
| 中间 CA          | ✅ 5–10 年                        | 中等——该 CA 的所有证书    | 很少                | 单 CA 提供商 App                |
| SPKI 哈希（代码）| ✅ 相同密钥续订时存活             | 高——特定密钥              | 仅密钥轮换时        | 动态锁定集、自定义逻辑          |
| NSPinnedDomains  | ✅ 相同密钥续订时存活             | 高——基于 SPKI             | 仅密钥轮换时        | **大多数 App 的默认选择**       |

---

## SecCertificate 和 SecIdentity

### 从 DER 数据创建证书

```swift
// ✅ 正确：从 App bundle 加载 .cer
guard let certURL = Bundle.main.url(forResource: "server", withExtension: "cer"),
      let certData = try? Data(contentsOf: certURL),
      let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
    fatalError("Failed to load certificate")
}

let summary = SecCertificateCopySubjectSummary(certificate) as String?
let publicKey = SecCertificateCopyKey(certificate)           // iOS 12+
let derBytes  = SecCertificateCopyData(certificate) as Data  // 往返到 DER
```

`SecCertificateCreateWithData` 仅接受 **DER 编码**数据——不接受 PEM。对于 PEM 文件，剥离 `-----BEGIN CERTIFICATE-----` 头/尾并 Base64 解码。

### 导入 PKCS#12 用于客户端证书认证

```swift
// ✅ 正确：导入 .p12 并提取 SecIdentity
func importIdentity(from p12Data: Data, password: String) throws -> SecIdentity {
    let options: [String: Any] = [kSecImportExportPassphrase as String: password]
    var rawItems: CFArray?
    let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)

    guard status == errSecSuccess,
          let items = rawItems as? [[String: Any]],
          let firstItem = items.first,
          let identity = firstItem[kSecImportItemIdentity as String] as? SecIdentity else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    return identity
}
```

`SecPKCS12Import` 的结果字典键：

- **`kSecImportItemIdentity`** (`SecIdentity`) —— 私钥 + 证书对
- **`kSecImportItemCertChain`** (`[SecCertificate]`) —— 完整证书链
- **`kSecImportItemTrust`** (`SecTrust`) —— 预配置的信任对象
- **`kSecImportItemKeyID`** (`Data`) —— 通常是公钥的 SHA-1 哈希

**永不要将密码与 App 打包。** 提示用户或从 Keychain 读取。

### URLSession 中的客户端证书认证

```swift
// ✅ 正确：同时处理服务器信任和客户端证书的双向 TLS 委托
class MutualTLSDelegate: NSObject, URLSessionDelegate {
    private let identity: SecIdentity
    private let certChain: [SecCertificate]?

    init(identity: SecIdentity, certChain: [SecCertificate]? = nil) {
        self.identity = identity
        self.certChain = certChain
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
                                                  URLCredential?) -> Void) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            let credential = URLCredential(
                identity: identity,
                certificates: certChain,
                persistence: .forSession
            )
            completionHandler(.useCredential, credential)

        case NSURLAuthenticationMethodServerTrust:
            guard let trust = challenge.protectionSpace.serverTrust,
                  SecTrustEvaluateWithError(trust, nil) else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))

        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
```

客户端证书挑战是**会话范围的**（`URLSessionDelegate`），而非任务特定的。App 必须在其沙箱内管理证书——它们无法访问通过 MDM 安装的系统范围证书。

### 证书链检查（向后兼容）

```swift
// ✅ 正确：向后兼容的链检查
func certificateChain(from trust: SecTrust) -> [SecCertificate] {
    if #available(iOS 15.0, macOS 12.0, *) {
        return SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
    } else {
        return (0..<SecTrustGetCertificateCount(trust)).compactMap {
            SecTrustGetCertificateAtIndex(trust, $0)
        }
    }
}
```

---

## AI 代码生成器产生的反模式

| 反模式                                                                  | 风险                                            | 正确替代                                                            |
| ----------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------- |
| 使用废弃的 `SecTrustEvaluate`                                           | 无错误上下文，iOS 13 废弃                       | `SecTrustEvaluateWithError` 或 `SecTrustEvaluateAsyncWithError`    |
| 全局禁用 ATS                                                            | 启用简单 MITM，触发 App Store 审查              | 开发用 `NSAllowsLocalNetworking`；生产用定向例外                    |
| `SecTrustSetAnchorCertificates` 不带 `SetAnchorCertificatesOnly(_, false)` | 静默禁用所有系统锚                              | 始终成对调用                                                        |
| `SecPolicyCreateSSL` 带 `nil` 主机名                                    | 禁用主机名验证——MITM 向量                       | 始终传递实际预期主机名                                              |
| 在锁定检查前跳过系统信任评估                                            | 过期/吊销证书通过锁定检查                        | 始终先 `SecTrustEvaluateWithError`，然后检查锁定                    |
| 使用 `SecTrustGetCertificateAtIndex`                                    | iOS 15 废弃                                     | `SecTrustCopyCertificateChain`（带向后兼容回退）                    |
| 使用 `SecTrustCopyPublicKey`                                            | iOS 14 废弃                                     | `SecCertificateCopyKey` 或 `SecTrustCopyKey`                        |
| 不带 ASN.1 头的 SPKI 哈希                                               | 产生错误哈希，锁定永不匹配                      | 在 SHA-256 前预置正确的 ASN.1 SPKI 头                               |
| 在 `.main` 队列上评估信任                                               | 网络相关检查期间 UI 冻结                        | 始终使用后台分发队列                                                |

```xml
<!-- ❌ 危险：永不发布此 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- ✅ 正确：仅开发用本地网络 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

---

## 备份锁定、轮换和优雅降级

**始终包含至少两个锁定。** 单个锁定意味着任何证书吊销、CA 入侵或计划外密钥轮换都会使你的 App 网络瘫痪。

**备份策略**：预生成备份密钥对，计算其 SPKI 哈希，将其作为锁定包含——不部署相应证书。如果主密钥被入侵，为备份密钥签发证书服务器端。App 已经信任它。

**当所有锁定失败时**：显示清晰错误说明服务器凭据无法验证，切换到离线/缓存模式，**永不允许用户绕过锁定**，记录用于诊断。恢复需要 App Store 更新（消费者 App）或 MDM 配置文件更新（托管部署）。

**OWASP 当前细致立场**：锁定应仅在你同时控制客户端和服务器、能安全更新锁定集并有清晰轮换策略时进行。证书透明度（自 iOS 12.1.1 起在 Apple 平台强制执行）加上 Apple 的吊销基础设施在不锁定的操作风险下提供了实质性保护。

---

## ATS 交互点

ATS 在所有 `URLSession` 连接上强制 TLS 1.2+、2048 位 RSA 或 256 位 ECC 密钥、SHA-256+ 哈希、AES-128/256 和前向保密。

**iOS 17 变化**：ATS 现在要求对裸 IP 地址（不仅仅是域名）的连接使用 HTTPS。

触发额外 App Store 审查的键：`NSAllowsArbitraryLoads`、`NSAllowsArbitraryLoadsForMedia`、`NSAllowsArbitraryLoadsInWebContent`、`NSExceptionAllowsInsecureHTTPLoads`、`NSExceptionMinimumTLSVersion`。

在 macOS 上使用 `nscurl --ats-diagnostics https://your-server.com` 诊断 ATS 兼容性。

---

## API 废弃时间线

| OS 版本              | 年份 | 关键变化                                                                               |
| -------------------- | ---- | -------------------------------------------------------------------------------------- |
| iOS 12 / macOS 10.14 | 2018 | 引入 `SecTrustEvaluateWithError`；强制执行证书透明度 (iOS 12.1.1)                      |
| iOS 13 / macOS 10.15 | 2019 | 引入 `SecTrustEvaluateAsyncWithError`；`SecTrustEvaluate` 废弃                         |
| iOS 14 / macOS 11    | 2020 | **引入 `NSPinnedDomains`**；`SecTrustCopyKey` 替代 `SecTrustCopyPublicKey`             |
| iOS 15 / macOS 12    | 2021 | **`SecTrustCopyCertificateChain`** 替代 `SecTrustGetCertificateAtIndex`/`Count`       |
| iOS 17 / macOS 14    | 2023 | ATS 对 IP 地址强制执行；EAP-TLS 1.3 支持                                              |
| iOS 18 / macOS 15    | 2024 | Swift 6 严格并发影响基于回调的 Security 代码；无新 SecTrust API                         |

---

## 线程安全和性能

- SecTrust 对象仅**跨不同实例**线程安全。永不要从多个线程访问同一 `SecTrust`。
- 不同的 `SecTrust` 对象可以在不同线程上并发评估。
- 在 iOS 上，所有 Certificate/Key/Trust Services 函数都是线程安全且可重入的。
- 在 macOS 上，信任评估可能**阻塞于用户交互**（keychain 解锁对话框）——始终在后台线程评估。
- `SecTrust`、`SecCertificate` 和 `SecKey` **未**标记为 `Sendable`。在 Swift 6 严格并发下，使用 `@unchecked Sendable` 包装器或显式 actor 隔离。

---

## CI/CD 护栏

- **如果**生产 `Info.plist` 中 `NSAllowsArbitraryLoads` 为 `true`，**则构建失败**。
- **验证**生产代码路径中 `SecPolicyCreateSSL` 永不以 `nil` 主机名调用。
- **强制**任何 `NSPinnedDomains` 条目包含至少两个 SPKI 哈希（备份锁定要求）。
- **扫描**废弃 API：`SecTrustEvaluate(`、`SecTrustGetCertificateAtIndex(`、`SecTrustCopyPublicKey(`。
- **在**生产部署前在暂存环境中用证书轮换测试锁定。

---

## 交叉验证说明

两个研究来源在所有主要建议上一致。并行来源中的关键差异（在本文件中已更正）：

1. **代码示例中的废弃 API**：并行来源使用 `SecTrustGetCertificateAtIndex(trust, 0)`——iOS 15 废弃。更正为 `SecTrustCopyCertificateChain`。
2. **缺少 ASN.1 头**：并行来源哈希原始密钥字节而不预置 SPKI ASN.1 头，产生错误哈希。用显式头预置更正。
3. **废弃的 `SecTrustCopyPublicKey` 引用**：并行来源引用此 API——iOS 14 废弃。更正为 `SecCertificateCopyKey`。
4. **主队列评估**：并行来源在 `.main` 队列上评估。更正为后台队列。

---

## 交叉引用

- `keychain-item-classes.md` —— `kSecClassCertificate` 和 `kSecClassIdentity` 存储、PKCS#12 导入模式
- `keychain-fundamentals.md` —— 证书和身份持久化的 SecItem CRUD 模式
- `cryptokit-public-key.md` —— PEM/DER 密钥互操作性、客户端证书的曲线选择
- `compliance-owasp-mapping.md` —— M5（不安全通信）信任评估要求

---

## WWDC 和参考引用

- **WWDC 2017 Session 709** —— "Your Apps and Evolving Network Security Standards"（ATS、CT、锁定指导）
- **Apple Developer Documentation** —— "Evaluating a Trust and Parsing the Result"、`SecTrustEvaluateAsyncWithError`、`NSPinnedDomains`
- **Apple Platform Security Guide** —— 吊销基础设施、证书透明度
- **Apple News Article** —— "Identity Pinning: How to configure server certificates for your app"
- **OWASP Pinning Cheat Sheet** —— 策略建议、备份锁定指导
- **OWASP MASTG** —— 证书锁定测试案例

---

## 总结清单

1. **信任评估使用现代 API** —— `SecTrustEvaluateWithError`（同步）或 `SecTrustEvaluateAsyncWithError`（异步）；无废弃的 `SecTrustEvaluate`
2. **信任评估在主线程外运行** —— 异步用后台分发队列；URLSession 委托回调同步时已离开主线程
3. **锁定策略避免叶证书** —— 使用 SPKI 哈希锁定、中间 CA 锁定或 `NSPinnedDomains`；生产中永不锁定原始叶证书字节
4. **配置至少两个锁定** —— 主 + 备份来自不同 CA 或预生成的备份密钥对
5. **锁定检查前评估系统信任** —— 始终先调用 `SecTrustEvaluateWithError`，然后比较 SPKI 哈希；永不跳过链验证
6. **SPKI 哈希包含 ASN.1 头** —— 在 SHA-256 哈希 `SecKeyCopyExternalRepresentation` 的原始密钥字节前预置正确的算法特定头
7. **自定义锚保留系统信任** —— `SecTrustSetAnchorCertificates` 与 `SecTrustSetAnchorCertificatesOnly(_, false)` 配对，除非有意限制
8. **SSL 策略绑定主机名** —— `SecPolicyCreateSSL` 始终接收实际预期主机名，永不 `nil`
9. **ATS 未全局禁用** —— 生产中无 `NSAllowsArbitraryLoads: true`；使用定向例外（`NSAllowsLocalNetworking`、按域例外）
10. **链检查使用当前 API** —— `SecTrustCopyCertificateChain` (iOS 15+) 对旧目标回退到 `SecTrustGetCertificateAtIndex`；`SecCertificateCopyKey` 而非 `SecTrustCopyPublicKey`
11. **客户端证书密码不打包** —— PKCS#12 密码运行时提示或存储在 Keychain，永不硬编码或嵌入 App bundle
