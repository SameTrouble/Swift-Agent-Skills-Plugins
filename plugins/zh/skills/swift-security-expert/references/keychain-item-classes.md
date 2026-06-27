# Keychain 条目类别

> 范围：所有五种 `kSecClass` 类型的正确类别选择和属性使用，重点在唯一性规则、AutoFill 行为和迁移安全。

五种 `kSecClass` 类型——GenericPassword、InternetPassword、Key、Certificate 和 Identity——各有不同角色和独特属性要求，AI 代码生成器经常搞错。**选择错误类别**导致静默 AutoFill 失败、查询碰撞和微妙安全退化。本参考涵盖每个类别及其复合主键、必需和可选属性、正确 Swift 模式和要注意的具体错误。

keychain 是为小密钥优化的加密 SQLite 数据库。每个条目类别定义一组属性形成**复合主键**——添加主键匹配现有条目的条目返回 `errSecDuplicateItem` (-25299)。理解这些主键是正确使用 keychain 的最重要概念。

**来源：** Apple Keychain Services 文档、TN3137（"On Mac keychain APIs and implementations"）、Quinn "The Eskimo!" DTS 帖子（"SecItem: Fundamentals"、"SecItem: Pitfalls and Best Practices"）、Apple Platform Security Guide、WWDC 2022–2024 passkey 会议、OWASP MASVS/MASTG。

---

## 按类别的复合主键

每个 `kSecClass` 定义形成其唯一性约束的特定属性集。`kSecAttrAccessGroup` 和 `kSecAttrSynchronizable` 参与所有类别的主键。

| 类别                | 主键属性                                                                                                                                | 典型用途                                       |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| **GenericPassword** | `kSecAttrService` + `kSecAttrAccount`                                                                                                   | 应用特定密钥、API 令牌、加密密钥                |
| **InternetPassword** | `kSecAttrServer` + `kSecAttrProtocol` + `kSecAttrPort` + `kSecAttrPath` + `kSecAttrAccount` + `kSecAttrSecurityDomain` + `kSecAttrAuthenticationType` | Web 凭据、服务器密码、AutoFill                  |
| **Key**             | `kSecAttrApplicationLabel` + `kSecAttrApplicationTag` + `kSecAttrKeyClass` + `kSecAttrKeyType` + `kSecAttrKeySizeInBits` + `kSecAttrEffectiveKeySize` | RSA/EC 密钥、对称密钥                          |
| **Certificate**     | `kSecAttrCertificateType` + `kSecAttrIssuer` + `kSecAttrSerialNumber`                                                                 | X.509 证书                                      |
| **Identity**        | 与 Certificate 相同（虚拟连接，非存储条目）                                                                                              | TLS 客户端认证、代码签名                        |

省略主键属性不导致错误——系统使用 nil/空默认。但带相同默认的第二次添加产生 `errSecDuplicateItem`，这是常见混淆来源。

---

## kSecClassGenericPassword — 应用特定密钥

GenericPassword 是 API 令牌、OAuth 刷新令牌、加密密钥和任何不代表 Web 登录凭据的密钥的正确选择。其主键实际上是 **`kSecAttrService` + `kSecAttrAccount`**。

**有意义使用所需**（API 不强制，但省略导致碰撞）：`kSecAttrService`（CFString——通常是 bundle ID 或服务标识符）和 `kSecAttrAccount`（CFString——账户或密钥名）。实际密钥放在 `kSecValueData` 中作为 `Data`。

**可选元数据属性：** `kSecAttrLabel`（人类可读名称）、`kSecAttrDescription`（条目类型）、`kSecAttrComment`（用户可编辑注释）、`kSecAttrCreator` 和 `kSecAttrType`（FourCharCode 作为 CFNumber）、`kSecAttrGeneric`（自定义元数据的任意 CFData）、`kSecAttrIsInvisible`/`kSecAttrIsNegative`（布尔标志）。系统管理只读：`kSecAttrCreationDate`、`kSecAttrModificationDate`。

### kSecAttrGeneric 陷阱

`kSecAttrGeneric` **不是主键的一部分**，尽管其名称暗示相反。两个带相同 `kSecAttrService` + `kSecAttrAccount` 但不同 `kSecAttrGeneric` 值的条目仍碰撞——第二次添加以 `errSecDuplicateItem` 失败。然而，按不匹配的 `kSecAttrGeneric` 查询返回 `errSecItemNotFound`，即使带该 service+account 的条目存在。此不一致是 bug 的主要来源。

```swift
// ✅ 应用特定 API 令牌的 GenericPassword
let addQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.myapp.api",
    kSecAttrAccount as String: "oauth-refresh-token",
    kSecValueData as String: tokenString.data(using: .utf8)!,
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    kSecUseDataProtectionKeychain as String: true
]
let status = SecItemAdd(addQuery as CFDictionary, nil)
```

**何时选择 GenericPassword vs InternetPassword：** 如果凭据属于 Web 域且你想要 AutoFill，使用 InternetPassword。GenericPassword 的 `kSecAttrService` 是对系统无语义意义的不透明字符串——它无法触发密码 AutoFill。

---

## kSecClassInternetPassword — AutoFill 和凭据共享

InternetPassword 专门为与网络服务关联的凭据存在。其**7 属性复合主键**使系统能将凭据匹配到域以用于密码 AutoFill、Safari 集成和跨设备同步。

主键属性：`kSecAttrServer`（主机名）、`kSecAttrProtocol`（如 `kSecAttrProtocolHTTPS`）、`kSecAttrPort`（CFNumber）、`kSecAttrPath`（URL 路径）、`kSecAttrAccount`（用户名）、`kSecAttrSecurityDomain`（HTTP realm）、`kSecAttrAuthenticationType`（如 `kSecAttrAuthenticationTypeHTMLForm`）。

**值得注意：** `kSecAttrGeneric` 和 `kSecAttrService` 对 InternetPassword **不可用**——server/protocol/path 属性起到等效目的。

### AutoFill 集成如何工作

密码 AutoFill 通过比较 `kSecAttrServer` 和关联域将凭据匹配到 App 和网站。完整集成需要三部分：

1. **将凭据存储为 InternetPassword**，`kSecAttrServer` 设置为网站域
2. **配置关联域**，通过在 App 的权限中添加 `webcredentials:<domain>`
3. **托管 apple-app-site-association 文件**，在 `https://<domain>/.well-known/apple-app-site-association`，包含 `{"webcredentials": {"apps": ["TEAMID.com.example.app"]}}`

三者都到位时，iOS QuickType 栏自动建议匹配凭据。Safari 将所有 Web 密码存储为 `kSecClassInternetPassword`——对 Web 凭据使用 GenericPassword 意味着系统永不能为 AutoFill 建议它们。

```swift
// ✅ 启用 AutoFill 的 InternetPassword
let addQuery: [String: Any] = [
    kSecClass as String: kSecClassInternetPassword,
    kSecAttrServer as String: "example.com",
    kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
    kSecAttrPort as String: 443,
    kSecAttrPath as String: "/login",
    kSecAttrAccount as String: "user@example.com",
    kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeHTMLForm,
    kSecValueData as String: "password123".data(using: .utf8)!,
    kSecUseDataProtectionKeychain as String: true
]
let status = SecItemAdd(addQuery as CFDictionary, nil)
```

```swift
// ❌ Web 凭据用 GenericPassword——AutoFill 永不发现这些
let badQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,       // 错误类别
    kSecAttrService as String: "example.com",             // 对 AutoFill 不透明
    kSecAttrAccount as String: "user@example.com",
    kSecValueData as String: "password123".data(using: .utf8)!
]
```

### 协议和认证常量

协议常量跨 **30+ 值**，包括 `kSecAttrProtocolHTTPS`、`kSecAttrProtocolHTTP`、`kSecAttrProtocolSSH`、`kSecAttrProtocolFTP`、`kSecAttrProtocolIMAPS`、`kSecAttrProtocolSMTP` 等。认证类型包括 `kSecAttrAuthenticationTypeHTMLForm`、`kSecAttrAuthenticationTypeHTTPBasic`、`kSecAttrAuthenticationTypeHTTPDigest` 和 `kSecAttrAuthenticationTypeDefault`。

### 凭据提供者扩展 (iOS 12+)

对于第三方密码管理器，`ASCredentialProviderViewController` 启用凭据提供者扩展。App 子类化此控制器，用 `ASPasswordCredentialIdentity` 实例填充 `ASCredentialIdentityStore`，并覆盖 `provideCredentialWithoutUserInteraction(for:)` 以实现点击填充行为。

---

## kSecClassKey — 加密密钥管理

密钥条目生成时需要 **`kSecAttrKeyType`** 和 **`kSecAttrKeySizeInBits`**——从 `SecKeyCreateRandomKey` 省略任一返回 `errSecParam` (-50)。`kSecAttrKeyClass` 属性（`kSecAttrKeyClassPublic`、`kSecAttrKeyClassPrivate`、`kSecAttrKeyClassSymmetric`）在生成时自动设置但查询时必须指定。

### ApplicationTag vs ApplicationLabel — 关键区别

此混淆是加密密钥最常见的单一 keychain 错误，AI 生成器经常搞错：

- **`kSecAttrApplicationTag`** (CFData)：**开发者设置**的二进制标签，用于查找和组织密钥。你选择其内容——通常是编码为 Data 的反向 DNS 字符串。主键的一部分。**用于查找。**
- **`kSecAttrApplicationLabel`** (CFData)：**系统生成**的公钥字节 SHA-1 哈希（按 RFC 5280 §4.1 的 `subjectPublicKey` 元素）。主键的一部分。**内部用于身份形成**——它必须匹配证书的 `kSecAttrPublicKeyHash` 以合成 `SecIdentity`。永不对非对称密钥手动设置。
- **`kSecAttrLabel`** (CFString)：人类可读显示名。**不是**主键的一部分。在 macOS 上的 Keychain Access 中显示。

### SecKeyCreateRandomKey — 首选 API

`SecKeyCreateRandomKey` (iOS 10+、macOS 10.12+) 原子地生成密钥，直接返回 `SecKey` 引用，自动计算 `kSecAttrApplicationLabel`，并通过 `kSecAttrTokenID: kSecAttrTokenIDSecureEnclave` 支持 Secure Enclave 生成。Apple 建议仅存储**私钥**并通过 `SecKeyCopyPublicKey()` 派生公钥。

```swift
// ✅ 带 SecKeyCreateRandomKey 的 EC 密钥创建
let tag = "com.myapp.keys.signing".data(using: .utf8)!
let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag
    ]
]
var error: Unmanaged<CFError>?
guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
    throw error!.takeRetainedValue() as Error
}
let publicKey = SecKeyCopyPublicKey(privateKey)!
```

```swift
// ✅ 带生物识别保护的 Secure Enclave 密钥
var accessError: Unmanaged<CFError>?
guard let accessControl = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .userPresence],
    &accessError
) else { throw accessError!.takeRetainedValue() as Error }

let tag = "com.myapp.keys.se-signing".data(using: .utf8)!
let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: accessControl
    ]
]
var genError: Unmanaged<CFError>?
guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &genError) else {
    throw genError!.takeRetainedValue() as Error
}
```

对密钥直接 `SecItemAdd` 仅在导入时合适——Apple 的"先导入再添加"模式通过 `SecKeyCreateWithData`。始终先创建 `SecKey` 对象；避免直接添加原始密钥数据。

### CryptoKit 密钥存储映射

CryptoKit 的 NIST 密钥（P256、P384、P521）通过带 `kSecAttrKeyTypeECSECPrimeRandom` 的 `SecKeyCreateWithData` 映射到 `SecKey`，存储为 `kSecClassKey`。**非 NIST 密钥**（Curve25519、SymmetricKey）无 `SecKey` 等效，必须作为 **`kSecClassGenericPassword`** 条目存储，原始密钥数据在 `kSecValueData` 中。Secure Enclave 密钥（`SecureEnclave.P256.Signing.PrivateKey`）导出只有原始 SE 可以恢复的加密 blob——此 blob 也存储为通用密码，而非密钥条目。

---

## kSecClassCertificate — DER 编码证书存储

证书**不被** keychain 加密（它们是公开数据）。主键是 `kSecAttrCertificateType` + `kSecAttrIssuer` + `kSecAttrSerialNumber`。

创建遵循两步模式：先从 DER 数据创建 `SecCertificate`，然后通过 `kSecValueRef` 添加：

```swift
// ✅ 添加证书
guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
    throw CertificateError.invalidDER  // 仅接受 DER，不接受 PEM
}
let addQuery: [String: Any] = [
    kSecClass as String: kSecClassCertificate,
    kSecValueRef as String: certificate,
    kSecUseDataProtectionKeychain as String: true
]
let status = SecItemAdd(addQuery as CFDictionary, nil)
```

通过 `kSecValueRef` 传递 `SecCertificate` 时，系统**自动提取** `kSecAttrIssuer`、`kSecAttrSerialNumber`、`kSecAttrSubject`、`kSecAttrPublicKeyHash`、`kSecAttrCertificateType` 和 `kSecAttrCertificateEncoding`。身份形成的关键属性是 **`kSecAttrPublicKeyHash`**——证书公钥的哈希，必须匹配私钥的 `kSecAttrApplicationLabel`。

**常见陷阱（Apple DTS）：** `kSecAttrApplicationTag` **不是证书的有效属性**（仅用于密钥）。与 `kSecClassCertificate` 一起使用在数据保护 keychain 上导致 `errSecParam` (-50)，或在基于文件的 keychain 上神秘静默失败。

---

## kSecClassIdentity — 虚拟连接

**keychain 不将数字身份存储为离散条目。** 身份是证书和其匹配私钥的逻辑连接，在查询时当证书的 `kSecAttrPublicKeyHash` 匹配私钥的 `kSecAttrApplicationLabel` 时合成——两个值都是公钥的 SHA-1 哈希。

### 为什么带 kSecClassIdentity 的 SecItemAdd 失败

尝试带 `kSecClass: kSecClassIdentity` 的 `SecItemAdd` 会以 `errSecParam` (-50) 失败。系统没有"身份表"。身份条目仅在匹配关系存在于分别存储的证书和密钥条目之间时出现。

级联影响：

- 当匹配私钥已存在时，添加**证书**可以隐式创建身份
- 当匹配证书已存在时，添加**私钥**可以隐式创建身份
- 删除证书或密钥可以隐式销毁身份
- 身份"集"在无显式身份操作的情况下变化

```swift
// ❌ 尝试直接创建身份——以 errSecParam (-50) 失败
let attributes: [String: Any] = [
    kSecClass as String: kSecClassIdentity,
    kSecAttrLabel as String: "MyInvalidIdentity"
]
let status = SecItemAdd(attributes as CFDictionary, nil)
// status == errSecParam (-50)
```

### 创建身份的三种正确方法

**方法 1：PKCS#12 导入**（服务器签发证书最常见）：

```swift
// ✅ 从 .p12 文件导入身份
let options: [String: Any] = [kSecImportExportPassphrase as String: "p12password"]
var items: CFArray?
let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
guard status == errSecSuccess,
      let results = items as? [[String: Any]],
      let identity = results.first?[kSecImportItemIdentity as String] as? SecIdentity else {
    throw IdentityError.importFailed
}
// 提取组件
var certificate: SecCertificate?
SecIdentityCopyCertificate(identity, &certificate)
var privateKey: SecKey?
SecIdentityCopyPrivateKey(identity, &privateKey)
```

**方法 2：分别添加证书和密钥**，带匹配的公钥哈希。两个条目必须在同一 keychain 实现中——在 macOS 上，两者必须使用 `kSecUseDataProtectionKeychain: true` 或两者都在基于文件的 keychain 中。

**方法 3：仅 macOS** —— `SecIdentityCreateWithCertificate` 给定证书引用搜索 keychain 以查找匹配私钥。

---

## AI 生成器搞错的正确性问题

### 1. 万事用 GenericPassword

AI 代码几乎普遍使用 `kSecClassGenericPassword` 带 `kSecAttrService` 用于 Web 凭据，完全错过 AutoFill 集成。正确模式使用 `kSecClassInternetPassword` 带 `kSecAttrServer` 和关联域。

### 2. 直接身份创建

生成代码尝试带 `kSecClassIdentity` 的 `SecItemAdd`，好像它是可存储条目类别。身份必须通过 PKCS#12 导入或分别添加匹配证书和密钥条目创建。

### 3. 缺少密钥类型属性

代码从密钥查询中省略 `kSecAttrKeyType`，在 RSA 和 EC 密钥间产生模糊匹配。由于密钥类型是复合主键的一部分，这是正确性 bug，非风格问题。

### 4. ApplicationTag / ApplicationLabel 混淆

生成代码将 `kSecAttrApplicationLabel` 设置为人类可读字符串，不理解它是用于身份匹配的自动生成公钥哈希。开发者设置的用于查找的标签是 `kSecAttrApplicationTag`。

### 5. 无重复处理

AI 代码调用 `SecItemAdd` 不处理 `errSecDuplicateItem`。正确模式要么尝试 update-first-then-add，要么捕获重复错误并调用 `SecItemUpdate`：

```swift
// ✅ Update-first 模式（首选）
var status = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
if status == errSecItemNotFound {
    var addQuery = searchQuery
    addQuery.merge(updateAttrs) { _, new in new }
    status = SecItemAdd(addQuery as CFDictionary, nil)
}
```

### 6. macOS 上缺少 kSecUseDataProtectionKeychain

没有此标志，macOS 默认为遗留基于文件的 keychain，导致 `kSecAttrAccessible`、`kSecAttrAccessGroup` 和生物识别访问控制被静默忽略或行为异常。

### 7. 在 Keychain 中存储大 blob

keychain 为小密钥设计。由于每条目检索的 Secure Enclave 解密延迟，存储大数据会退化性能。对超过几 KB 的任何内容使用信封加密。

---

## 现代 API 模式和平台差异

### kSecUseDataProtectionKeychain 统一跨平台行为

在 **iOS/tvOS/watchOS** 上，数据保护 keychain 是唯一实现——此标志被忽略。在 **macOS 原生 App** 上，`SecItem` 默认为遗留基于文件的 keychain。设置 `kSecUseDataProtectionKeychain: true` 切换到数据保护 keychain，提供与 iOS 相同的行为。在 **Mac Catalyst** App 上，数据保护是默认。

Apple 明确建议为所有 keychain 操作将此标志设置为 `true`。基于文件的 keychain 正在废弃路径上（`SecKeychainCreate` 在 macOS 12 中废弃）。

### TN3137 关键要点

TN3137 文档记录了 macOS 的**三种 keychain API**（遗留 Keychain、SecKeychain 和推荐的 SecItem）和**两种实现**（基于文件和数据保护）。关键路由规则：只有 `SecItem` 可以目标任一实现；`SecKeychain` 始终目标基于文件。数据保护 keychain 在 macOS 上需要代码签名和配置文件。

微妙行为差异：`SecItemDelete` 在数据保护 keychain 上默认为 `kSecMatchLimitAll`（删除所有匹配条目），但在基于文件的 keychain 上为 `kSecMatchLimitOne`——Apple bug 跟踪器中记录的不一致（r. 105800863）。

### iCloud Keychain 同步限制

`kSecAttrSynchronizable` 必须显式设置为 `true`——条目默认不同步。**所有五种类别**在 iOS 14+ / macOS 11+ / watchOS 7+ 上支持同步；早期版本仅同步密码类别。

关键限制：

- 带 "ThisDeviceOnly" 可访问性的条目**不能**同步——将 `kSecAttrSynchronizable: true` 与任何 `ThisDeviceOnly` 可访问性组合返回 `errSecParam` (-50)
- 持久引用不支持可同步条目
- tvOS 接受属性但从不实际同步
- 更新和删除传播到跨设备的所有副本

---

## 大小限制、性能和何时使用文件

Apple 将 keychain 描述为存储**"小密钥"**而未发布硬大小限制。底层 SQLite 支持最多约 **16 MB** 的条目（`SQLITE_MAX_LENGTH`），但这绝非预期用途。

### 性能架构

keychain 有直接性能影响：**元数据由缓存的 Application Processor 密钥加密**（启用快速属性查询），而**密钥值每次访问需要 Secure Enclave 往返**。这意味着仅 `kSecReturnAttributes` 的查询比 `kSecReturnData` 查询快得多。始终只请求你需要的。

查询优化规则：

1. **使用完整复合键** —— 宽泛查询强制 `securityd` 执行慢数据库扫描
2. **限制匹配** —— 预期单个条目时使用 `kSecMatchLimitOne` 以提前终止搜索
3. **先获取元数据** —— 如果只需检查存在性，不要请求 `kSecReturnData`

### 大数据的信封加密

对超过几 KB 的数据，使用 **DEK/KEK 模式**：在 keychain 中存储 32 字节 AES-256 数据加密密钥 (DEK)，用该密钥加密实际数据，将密文写入由 `NSFileProtection` 保护的文件。OWASP MASTG 推荐此模式用于 MASVS L2 合规。

可访问性到文件保护的映射：

- `kSecAttrAccessibleWhenUnlocked` → `NSFileProtectionComplete`
- `kSecAttrAccessibleAfterFirstUnlock` → `NSFileProtectionCompleteUntilFirstUserAuthentication`

### 用 kSecReturnAttributes 查询元数据检查

```swift
// ✅ 检查 GenericPassword 条目的所有元数据
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.myapp.api",
    kSecReturnAttributes as String: true,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]
var item: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &item)
guard status == errSecSuccess, let attrs = item as? [String: Any] else { return }

// 返回字典中的可用元数据：
let account = attrs[kSecAttrAccount as String] as? String
let service = attrs[kSecAttrService as String] as? String
let created = attrs[kSecAttrCreationDate as String] as? Date
let modified = attrs[kSecAttrModificationDate as String] as? Date
let accessible = attrs[kSecAttrAccessible as String] as? String
let syncable = attrs[kSecAttrSynchronizable as String] as? Bool
let secretData = attrs[kSecValueData as String] as? Data
```

当 `kSecReturnAttributes` 和 `kSecReturnData` 都为 true 且带 `kSecMatchLimitOne` 时，结果是包含所有元数据和 `kSecValueData` 下密钥数据的单个字典。带 `kSecMatchLimitAll` 时，是此类字典的数组。

---

## 类别正确性测试矩阵

| 测试场景                                            | 预期 OSStatus              | 理由                                         |
| --------------------------------------------------- | -------------------------- | -------------------------------------------- |
| 通过 `SecItemAdd` 添加 `kSecClassIdentity`          | `errSecParam` (-50)        | 身份必须导入，不能直接创建                   |
| 不带 `kSecAttrKeyType` 添加 `kSecClassKey`          | `errSecParam` (-50)        | 加密元数据严格必需                           |
| 添加带相同复合主键的条目                            | `errSecDuplicateItem` (-25299) | 需要 `SecItemUpdate` 或 delete-then-add      |
| 同步 `true` + `ThisDeviceOnly` 可访问性             | `errSecParam` (-50)        | 矛盾约束                                     |
| 将 `kSecAttrApplicationTag` 与 `kSecClassCertificate` 一起使用 | `errSecParam` (-50)        | 标签仅对密钥条目有效                         |
| 不带 `kSecAttrKeyClass` 查询 `kSecClassKey`         | 可能返回错误密钥类别       | 公/私/对称间模糊匹配                         |

---

## 迁移：GenericPassword 到 InternetPassword

如果你的应用当前将 Web 凭据存储为 `kSecClassGenericPassword`，迁移到 `kSecClassInternetPassword` 以启用 AutoFill：

```swift
// ✅ 迁移模式：GenericPassword → InternetPassword
func migrateWebCredentials() throws {
    // 1. 查询现有 GenericPassword 条目中的 Web 凭据
    let oldQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "www.example.com",
        kSecReturnAttributes as String: true,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll
    ]

    var items: CFTypeRef?
    let fetchStatus = SecItemCopyMatching(oldQuery as CFDictionary, &items)
    guard fetchStatus == errSecSuccess,
          let results = items as? [[String: Any]] else { return }

    for item in results {
        guard let account = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data else { continue }

        // 2. 添加为带正确属性的 InternetPassword
        let newQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: "www.example.com",
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecUseDataProtectionKeychain as String: true
        ]
        let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else { continue }

        // 3. 删除旧 GenericPassword 条目
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "www.example.com",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
    }
}
```

---

## 交叉引用索引

- **SecItem CRUD 操作、查询字典、错误处理** → `keychain-fundamentals.md`
- **可访问性常量、SecAccessControl 标志** → `keychain-access-control.md`
- **密钥和密码的生物识别保护** → `biometric-authentication.md`
- **Secure Enclave 密钥生成和约束** → `secure-enclave.md`
- **CryptoKit 密钥类型和 keychain 存储映射** → `cryptokit-symmetric.md`、`cryptokit-public-key.md`
- **OAuth 令牌、API 密钥、凭据生命周期** → `credential-storage-patterns.md`
- **访问组、App 扩展、共享** → `keychain-sharing.md`
- **SecCertificate、SecTrust、信任评估** → `certificate-trust.md`
- **遗留迁移模式** → `migration-legacy-stores.md`
- **AI 生成代码反模式** → `common-anti-patterns.md`
- **OWASP MASVS/MASTG 合规** → `compliance-owasp-mapping.md`

---

## 结论

keychain 的五种类别形成精确分类法：GenericPassword 用于应用本地密钥，InternetPassword 用于域关联凭据启用 AutoFill，Key 用于加密材料及其 tag/label 区别，Certificate 用于公开 X.509 数据，Identity 作为从匹配证书和密钥条目涌现的虚拟构造。最有影响的决策是对 Web 凭据选择 InternetPassword 而非 GenericPassword，始终设置 `kSecUseDataProtectionKeychain` 以跨平台一致，理解身份不能直接创建，以及认识 `kSecAttrApplicationTag`（开发者设置，用于查找）vs `kSecAttrApplicationLabel`（系统生成，用于身份匹配）是尽管名称相似但根本不同的属性。

---

## 总结清单

1. **正确类别选择** —— 对任何与 Web 域关联的凭据使用 `kSecClassInternetPassword`（而非 GenericPassword）以启用 AutoFill
2. **复合主键完整性** —— 为所选类别包含所有主键属性以避免 `errSecDuplicateItem` 碰撞和查询遗漏
3. **kSecAttrGeneric 不是主键** —— 不要依赖它用于 GenericPassword 条目的唯一性；它导致不对称的添加/查询行为
4. **ApplicationTag vs ApplicationLabel** —— 使用 `kSecAttrApplicationTag`（开发者设置，CFData）用于密钥查找；永不手动设置 `kSecAttrApplicationLabel`（系统生成的用于身份匹配的哈希）
5. **通过导入创建身份** —— 永不 `SecItemAdd` 带 `kSecClassIdentity`；使用 `SecPKCS12Import` 或分别添加匹配的证书 + 密钥对
6. **密钥类型和大小必需** —— 创建或查询 `kSecClassKey` 条目时始终指定 `kSecAttrKeyType` 和 `kSecAttrKeySizeInBits`
7. **macOS 上 kSecUseDataProtectionKeychain** —— 为所有操作设置为 `true` 以获得与 iOS 相同的行为并避免静默遗留 keychain 回退
8. **同步和可访问性一致** —— 永不将 `kSecAttrSynchronizable: true` 与 "ThisDeviceOnly" 可访问性值组合
9. **仅小密钥** —— 对超过几 KB 的数据使用信封加密（DEK 在 keychain，密文在 `NSFileProtection` 保护文件中）
10. **证书属性** —— 永不将 `kSecAttrApplicationTag` 与 `kSecClassCertificate` 一起使用；让系统通过 `kSecValueRef` 提取元数据
11. **重复处理** —— 始终用 update-first-then-add 或 delete-then-add 模式处理 `errSecDuplicateItem`
