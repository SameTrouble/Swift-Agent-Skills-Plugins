# 合规性与 OWASP 映射参考

> 范围：将 Apple 平台客户端安全模式映射到 OWASP Mobile Top 10 (2024)、MASVS 和 MASTG 控制，用于审计和修复工作流。

**大多数 AI 代码生成器仍引用 2016 年 OWASP Mobile Top 10 编号——"M2：不安全数据存储"、"M5：加密不足"——这在 2024 年被完全替换。** 本参考将当前 iOS 安全实践映射到 OWASP Mobile Top 10 (2024)、MASVS v2.1.0 和 MASTG 测试案例，用于 2024–2026 合规窗口。它涵盖与 Keychain 和安全工作最相关的四个类别：M1（不当凭据使用）、M3（不安全认证/授权）、M9（不安全数据存储）和 M10（加密不足）。Cybernews 对 156,080 个 iOS App 的分析（2025 年 3 月）发现 71% 泄露至少一个硬编码密钥——CISA/FBI 在 2025 年 1 月联合将硬编码凭据归类为"危险"坏实践（CWE-798）。

---

## 变化：2016 → 2024 OWASP Mobile Top 10

2024 版是全面改革。四个类别完全新增，两对合并，一切都重新编号。任何引用 2016 编号的代码注释或文档都已过时。

| 2024 类别                                      | 状态        | 2016 前身          |
| --------------------------------------------- | ----------- | ------------------ |
| **M1：不当凭据使用**                           | 新增        | 无                 |
| **M2：供应链安全不足**                         | 新增        | 无                 |
| **M3：不安全认证/授权**                        | 合并        | 2016 M4 + M6       |
| **M4：输入/输出验证不足**                      | 新增        | 无                 |
| **M5：不安全通信**                             | 重新编号    | 2016 M3            |
| **M6：隐私控制不足**                           | 新增        | 无                 |
| **M7：二进制保护不足**                         | 合并        | 2016 M8 + M9       |
| **M8：安全配置错误**                           | 扩展        | 2016 M10（部分）   |
| **M9：不安全数据存储**                         | 重新编号    | 2016 M2            |
| **M10：加密不足**                              | 重新编号    | 2016 M5            |

**MASVS v2.1.0**（2024 年 1 月 18 日）重组为 8 个控制组，带简洁、可测试的控制。旧的 L1/L2/R 验证级别成为 MASTG 内的 **MAS Testing Profiles**，与 NIST OSCAL 对齐。旧版 MSTG-\* 测试 ID（例如 MSTG-STORAGE-1）被废弃，取而代之的是新的 MASTG-TEST-02xx/03xx 标识符，带细粒度、工具特定的测试程序。

---

## 主追溯矩阵

此矩阵将每个 OWASP 2024 类别链接到其 MASVS 控制、MASTG 测试案例、iOS API 和所需审计证据。两个研究来源在核心映射上一致；此表统一了它们。

| OWASP 2024                        | MASVS v2 控制                                 | 关键 MASTG 测试（新 ID）                                         | iOS API / 标志                                                                          | 所需证据                                                           |
| --------------------------------- | --------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **M1** 不当凭据使用  | MASVS-STORAGE-1、MASVS-AUTH-1、MASVS-CRYPTO-2 | 0213、0214、0299、0300、0302                                     | Keychain + `SecAccessControl`；App Attest                                               | 静态扫描（无字面量）；带 ACL 的 keychain 转储；认证日志             |
| **M3** 不安全认证/授权        | MASVS-AUTH-1、MASVS-AUTH-2、MASVS-AUTH-3      | 0266、0267、0268、0269、0270、0271                               | `SecAccessControlCreateWithFlags` + `.biometryCurrentSet`；`ASWebAuthenticationSession` | 认证流程图；生物识别绕过测试结果；令牌 TTL 策略                     |
| **M9** 不安全数据存储      | MASVS-STORAGE-1、MASVS-STORAGE-2              | 0296、0297、0299、0300、0301、0302、0303、0215、0298、0313、0314 | Keychain 可访问性标志；`NSFileProtectionComplete`；`isExcludedFromBackup`                | `xattr` 列表；备份提取；keychain 转储                               |
| **M10** 加密不足 | MASVS-CRYPTO-1、MASVS-CRYPTO-2                | 0209、0210、0211、0213、0214、0311、0317                         | CryptoKit `AES.GCM`/`ChaChaPoly`；`SecRandomCopyBytes`；Secure Enclave 密钥             | 加密清单；算法审计；单元测试                                        |

> **交叉引用说明：** MASVS-STORAGE-1 和 MASTG-TEST-0299/0302 同时出现在 M1 和 M9 下。这是有意的——keychain 配置同时解决凭据存储和静态数据保护。见 `keychain-access-control.md` 了解详细的可访问性标志指导。

---

## M1 — 不当凭据使用

**范围：** 源码/配置中的硬编码凭据、不安全凭据传输、不安全设备上存储、弱认证协议。攻击向量：EASY。影响：SEVERE。2024 年完全新增——无 2016 前身。

**Cybernews 2025 数据：** 156,080 个 iOS App 中有 815,000+ 硬编码密钥（平均每个 App 5.2 个），包括 19 个 Stripe 密钥、836 个未保护的云端点暴露 406TB，以及 2,218 个配置错误的 Firebase 端点泄露 19.8M 条记录。在明文 IPA 文件中发现密钥而无需反编译。

### MASTG 测试案例

| 测试 ID          | 旧版 ID        | 验证                                              | 配置文件 |
| ---------------- | -------------- | ------------------------------------------------- | -------- |
| MASTG-TEST-0213  | MSTG-CRYPTO-1  | 源码/二进制中无硬编码加密密钥                      | L1, L2   |
| MASTG-TEST-0214  | MSTG-CRYPTO-5  | bundle 文件中无加密密钥（plist、config）           | L1, L2   |
| MASTG-TEST-0299  | MSTG-STORAGE-1 | 文件使用适当的数据保护类别                         | L1       |
| MASTG-TEST-0300  | MSTG-STORAGE-1 | 静态：对存储未加密数据的 API 引用                  | L2       |
| MASTG-TEST-0302  | MSTG-STORAGE-2 | 私有存储中的敏感数据未加密                         | L2       |

**测试流程：** 使用 radare2 进行静态分析——搜索带硬编码密钥数据的 `SecKeyCreateWithData` 或带内联字节的 CryptoKit 密钥初始化。运行时使用 objection（`ios keychain dump`、`ios nsuserdefaults get`）和文件系统 grep。检查 `.xcconfig`、`Info.plist` 和嵌入资源中的 API 密钥。

**App Attest (iOS 14+)：** 在服务器签发凭据前验证设备完整性，关闭密钥配置差距。这完全避免硬编码密钥——服务器仅向认证的、真实的 App 实例配置密钥。见 `credential-storage-patterns.md` 了解实现细节。

### 合规：Keychain 凭据存储

```swift
import Security

/// 安全地将凭据存储在 iOS Keychain 中。
/// 合规：OWASP M1（不当凭据使用）、MASVS-STORAGE-1
/// 测试案例：MASTG-TEST-0213、MASTG-TEST-0299
/// iOS 8.0+（SecAccessControlCreateWithFlags）、iOS 11.3+（.biometryCurrentSet）
func storeCredential(account: String, secret: Data, service: String) throws {
    // ✅ 正确——密钥通过显式访问控制持久化在 Keychain 中
    // 先删除现有条目以避免 errSecDuplicateItem
    let deleteQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
    ) else {
        throw error!.takeRetainedValue() as Error
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: service,
        kSecAttrAccessControl as String: accessControl,
        kSecValueData as String: secret
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
```

### 反模式：常见 AI 生成的凭据存储

```swift
// ❌ 错误——UserDefaults 写入未加密 plist 到：
//   <AppSandbox>/Library/Preferences/<BundleID>.plist
// 可通过 iTunes 备份、iMazing 或 objection 提取
UserDefaults.standard.set(apiToken, forKey: "auth_token")

// ❌ 错误——源码中硬编码 API 密钥（71% 的 iOS App 中发现）
let stripeKey = "sk_live_4eC39HqLyjWDarjtT1zdp7dc"

// ❌ 错误——Info.plist 中的密钥（IPA 归档中明文）
// <key>API_SECRET</key><string>my-secret-key-12345</string>

// ❌ 错误——NSKeyedArchiver 到 Documents 目录（无加密）
let data = try NSKeyedArchiver.archivedData(
    withRootObject: credentials, requiringSecureCoding: true)
try data.write(to: documentsURL.appendingPathComponent("creds.dat"))
```

**为何这些未通过审计：** objection `ios nsuserdefaults get` 立即揭示 UserDefaults。MobSF 标记硬编码密钥模式。备份提取暴露 Documents 目录。全部未通过 MASTG-TEST-0213 和 MASTG-TEST-0302。

---

## M3 — 不安全认证/授权

**范围：** 合并 2016 M4 + M6。涵盖远程服务端认证、本地生物识别认证和仅客户端授权。攻击向量：EASY。影响：SEVERE。关键 iOS 风险：仅 LAContext 生物识别认证可通过 Frida 在 10 秒内绕过。

### MASTG 测试案例

| 测试 ID          | 旧版 ID      | 验证                                                      | 配置文件 |
| ---------------- | ------------ | --------------------------------------------------------- | -------- |
| MASTG-TEST-0266  | MSTG-AUTH-8  | 静态：对 `LAContext.evaluatePolicy` 的引用                | L2       |
| MASTG-TEST-0267  | MSTG-AUTH-8  | 动态：运行时基于事件的生物识别认证（可绕过）              | L2       |
| MASTG-TEST-0268  | MSTG-AUTH-8  | 静态：允许回退到非生物识别认证的 API                      | L2       |
| MASTG-TEST-0269  | MSTG-AUTH-8  | 动态：运行时回退到非生物识别认证                          | L2       |
| MASTG-TEST-0270  | MSTG-AUTH-8  | 静态：用于注册变更检测的 `.biometryCurrentSet`            | L2       |
| MASTG-TEST-0271  | MSTG-AUTH-8  | 动态：运行时强制执行注册变更检测                          | L2       |

### LAContext 漏洞

`LAContext.evaluatePolicy` 执行仅软件的生物识别检查，在完成处理器中返回布尔。此布尔在用户空间执行，可被 Frida hook 以始终返回 `true`。Secure Enclave 执行生物识别匹配，但结果是一个普通回调，无认证的加密证明。

**Frida 绕过（< 10 行）：**

```javascript
// 强制 LAContext.evaluatePolicy 始终成功
if (ObjC.available) {
  var hook = ObjC.classes.LAContext["- evaluatePolicy:localizedReason:reply:"];
  Interceptor.attach(hook.implementation, {
    onEnter: function (args) {
      var block = new ObjC.Block(args[4]);
      const appCallback = block.implementation;
      block.implementation = function (error, value) {
        return appCallback(1, null); // 强制 success=true
      };
    },
  });
}
```

**objection 一行命令：** `ios ui biometrics_bypass` —— hook `evaluatePolicy` 返回 `true`。

正确模式将密钥绑定到由 `SecAccessControlCreateWithFlags` 保护的 Keychain 条目。Secure Enclave 持有解密密钥，没有有效生物识别认证就不会释放。没有可 hook 的布尔——生物识别失败意味着数据在加密上不可访问。

### `.biometryCurrentSet` vs `.biometryAny`

| 标志                  | 行为                                              | 安全性                                             | iOS   |
| --------------------- | ------------------------------------------------- | ---------------------------------------------------- | ----- |
| `.biometryCurrentSet` | 注册新生物识别时条目失效                           | **推荐**——防止注册变更攻击                          | 11.3+ |
| `.biometryAny`        | 任何已注册生物识别可访问，即使是新注册的           | 较低——攻击者可添加自己的指纹                        | 11.3+ |
| `.userPresence`       | 生物识别或密码（系统选择）                         | 允许密码回退                                        | 8.0+  |
| `.devicePasscode`     | 仅密码                                             | 无生物识别选项                                       | 9.0+  |

对于高安全性条目，始终使用 `.biometryCurrentSet`。如果攻击者在被盗设备上添加指纹，`.biometryAny` 条目变得可访问；`.biometryCurrentSet` 条目被永久失效。见 `biometric-authentication.md` 了解完整实现模式。

### 合规：硬件绑定的生物识别认证

```swift
import LocalAuthentication
import Security

/// 使用 Keychain + Secure Enclave 的硬件绑定生物识别认证。
/// 合规：OWASP M3（不安全认证）、MASVS-AUTH-2
/// 测试案例：MASTG-TEST-0266、MASTG-TEST-0270
/// iOS 11.3+（.biometryCurrentSet）
/// 带完整错误处理的规范模式：biometric-authentication.md § 安全模式——硬件绑定的密钥

// 步骤 1：存储带生物识别保护的密钥
func storeBiometricProtectedSecret(account: String, secret: Data) throws {
    // ✅ 正确——Secure Enclave 通过 keychain ACL 门控密钥释放
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        &error
    ) else {
        throw error!.takeRetainedValue() as Error
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: "com.app.biometric-auth",
        kSecAttrAccessControl as String: accessControl,
        kSecValueData as String: secret
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}

// 步骤 2：检索——Secure Enclave 强制生物识别检查
func retrieveBiometricProtectedSecret(account: String) throws -> Data? {
    let context = LAContext()
    context.localizedReason = "Authenticate to access your account"

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecAttrService as String: "com.app.biometric-auth",
        kSecUseAuthenticationContext as String: context,
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess else { return nil }
    return result as? Data
}
```

### 反模式：仅 LAContext 认证

```swift
// ❌ 错误——#2 最常见 iOS 审计发现
// 可绕过：objection -g com.app explore -> ios ui biometrics_bypass
let context = LAContext()
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Log in") { success, error in
    if success {
        // ❌ 此布尔可 hook——无加密证明
        self.showMainScreen()  // 攻击者获得完全访问
    }
}
```

---

## M9 — 不安全数据存储

**范围：** App 存储敏感数据的所有漏洞：弱/无加密、可访问位置、访问控制不足、意外泄露（日志、缓存、备份）。2016 年是 M2——重新编号为 M9（优先级转移，非重要性降低）。

### iOS 存储安全属性

| 存储位置                           | 加密              | 在备份中       | 越狱后可访问           | 结论                         |
| ---------------------------------- | ----------------- | -------------- | ---------------------- | ---------------------------- |
| Keychain (`WhenPasscodeSetThisDeviceOnly`) | ✅ AES-256-GCM     | ❌             | ❌                       | ✅ 用于密钥                  |
| Keychain (`AfterFirstUnlock`)      | ✅                 | ✅（加密）     | ❌                       | ⚠️ L1 可接受                 |
| `NSFileProtectionComplete` 文件    | ✅（锁定时）       | ✅             | ❌                       | ✅ 用于敏感文件              |
| UserDefaults                       | ❌ 明文 plist      | ✅             | ✅（通过备份）          | ❌ 永不用于密钥              |
| Documents/（默认保护）             | ✅（Class C）      | ✅             | ✅（通过备份）          | ❌ 无额外加密不可            |
| SQLite/CoreData（无 SQLCipher）    | ❌                 | ✅             | ✅（通过备份）          | ❌ 不用于密钥                |
| NSLog 输出                         | ❌                 | N/A            | ✅（Console.app）       | ❌ 永不记录密钥              |

**Keychain 持久化说明：** Keychain 条目在 App 卸载后存活并在安装/卸载周期中持久（自 iOS 10.3 确认）。仅恢复出厂设置清除它们。例外：`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` 条目在移除密码时被删除。

### MASTG 测试案例

| 测试 ID          | 旧版 ID        | 验证                                          | 配置文件 |
| ---------------- | -------------- | --------------------------------------------- | -------- |
| MASTG-TEST-0299  | MSTG-STORAGE-1 | 私有存储文件的数据保护类别                     | L1       |
| MASTG-TEST-0300  | MSTG-STORAGE-1 | 静态：对未加密存储 API 的引用                  | L2       |
| MASTG-TEST-0301  | MSTG-STORAGE-1 | 动态：运行时使用未加密存储                     | L2       |
| MASTG-TEST-0302  | MSTG-STORAGE-2 | 私有存储中的敏感数据未加密                     | L2       |
| MASTG-TEST-0296  | MSTG-STORAGE-3 | 日志中的敏感数据                               | L1, L2   |
| MASTG-TEST-0297  | MSTG-STORAGE-3 | 将敏感数据插入日志语句                         | L1, L2   |
| MASTG-TEST-0215  | MSTG-STORAGE-8 | 敏感数据未从备份排除                           | L1, L2   |
| MASTG-TEST-0313  | MSTG-STORAGE-5 | 防止键盘缓存的 API                             | L1, L2   |

### NSFileProtection 类别

| 类别               | 常量                                               | 何时可访问                                           | 默认？   |
| ------------------- | -------------------------------------------------- | ---------------------------------------------------- | -------- |
| A：Complete         | `NSFileProtectionComplete`                         | 仅解锁时；锁定后约 10 秒丢弃密钥                     | 否       |
| B：Unless Open      | `NSFileProtectionCompleteUnlessOpen`               | 已打开的文件在锁定时仍可访问                         | 否       |
| C：Until First Auth | `NSFileProtectionCompleteUntilFirstUserAuthentication` | 首次解锁后，即使锁定                                 | **是**   |
| D：None             | `NSFileProtectionNone`                             | 始终；仅受设备 UID 保护                               | 否       |

### 合规：带数据保护的文件存储

```swift
import Foundation

/// 带 Complete 文件保护写入敏感数据。
/// 合规：OWASP M9（不安全数据存储）、MASVS-STORAGE-1
/// 测试案例：MASTG-TEST-0299
/// iOS 9.0+（.completeFileProtection 选项）
func writeProtectedFile(data: Data, to url: URL) throws {
    try data.write(to: url, options: [.atomic, .completeFileProtection])
}

/// 从设备备份排除文件。
/// 合规：MASVS-STORAGE-2、MASTG-TEST-0215
/// iOS 5.1+
func excludeFromBackup(url: URL) throws {
    var resourceURL = url
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    try resourceURL.setResourceValues(resourceValues)
}
```

### 反模式：不安全数据存储

```swift
// ❌ 错误——未加密 plist
UserDefaults.standard.set("Bearer eyJhbGciOiJSUzI1NiIs...", forKey: "authToken")

// ❌ 错误——敏感文件的默认文件保护（Class C）
try sensitiveData.write(to: documentsURL.appendingPathComponent("profile.dat"))

// ❌ 错误——记录敏感数据（Console.app / idevicesyslog）
NSLog("User token: %@", authToken)
print("Password entered: \(password)")

// ❌ 错误——未从备份排除敏感文件
// Documents/ 中的文件默认在 iTunes/Finder 备份中
// 非越狱设备上可用 iMazing 提取
```

---

## M10 — 加密不足

**范围：** 弱算法、密钥长度不足、密钥管理不当、不安全 RNG、废弃哈希。攻击向量：AVERAGE。影响：SEVERE。2016 年是 M5。

### 废弃 vs 批准的算法

| 类别       | ❌ 废弃/破损              | ✅ 批准（CryptoKit，iOS 13+）                               |
| ---------- | ------------------------- | ----------------------------------------------------------- |
| 哈希       | MD5、SHA-1（用于安全）    | SHA256、SHA384、SHA512；SHA3 (iOS 18+)                      |
| 对称       | DES、3DES、RC4、Blowfish、AES-ECB | AES.GCM (AES-256-GCM)、ChaChaPoly                          |
| 非对称     | RSA < 2048 位             | P256、P384、P521、Curve25519、Ed25519                      |
| 密钥派生   | 简单密码 SHA 哈希         | HKDF；服务端 Argon2/bcrypt/scrypt                           |
| RNG        | `rand()`、`random()`、`srand()` | `SecRandomCopyBytes` (iOS 2+)、CryptoKit 自动 nonce (iOS 13+) |
| 后量子     | 所有经典 PKC（到 2030 年）| ML-KEM、ML-DSA、X-Wing (iOS 26+)                            |

**`arc4random()` 细微差别：** 在现代 Apple 平台上，`arc4random()` 内部使用 CSPRNG（非破损 RC4）。它在 iOS 上技术上安全。然而，`SecRandomCopyBytes` 仍推荐用于显式加密使用——其安全保证有文档记录且跨平台可移植。见 `cryptokit-symmetric.md` 了解详细算法指导。

**AES-GCM nonce 重用是灾难性的：** 与相同密钥的单次重用破坏保密性（密文 XOR 揭示明文 XOR）和认证（泄露 GHASH 密钥 `H`，启用任意伪造）。CryptoKit 通过在调用 `AES.GCM.seal()` 不带显式 nonce 时自动生成随机 nonce 来缓解。

### MASTG 测试案例

| 测试 ID          | 旧版 ID      | 验证                                        | 配置文件 |
| ---------------- | ------------ | ------------------------------------------- | -------- |
| MASTG-TEST-0209  | MSTG-CRYPTO-2 | 密钥大小满足最低要求                         | L1, L2   |
| MASTG-TEST-0210  | MSTG-CRYPTO-2 | 无破损对称算法（DES、3DES、RC4）             | L1, L2   |
| MASTG-TEST-0211  | MSTG-CRYPTO-3 | 无破损哈希（MD5、SHA-1 用于安全）            | L1, L2   |
| MASTG-TEST-0317  | MSTG-CRYPTO-3 | 无破损加密模式（ECB）                        | L1, L2   |
| MASTG-TEST-0311  | MSTG-CRYPTO-6 | 使用 CSPRNG（非 `rand`/`random`）            | L1, L2   |
| MASTG-TEST-0213  | MSTG-CRYPTO-1 | 代码中无硬编码加密密钥                       | L1, L2   |
| MASTG-TEST-0214  | MSTG-CRYPTO-5 | 文件中无硬编码加密密钥                       | L1, L2   |

**iOS 特定测试：** 使用 radare2 查找 CommonCrypto 调用中对 `kCCAlgorithmDES`、`kCCAlgorithm3DES`、`kCCAlgorithmRC4`、`kCCOptionECBMode` 的引用。搜索 `CC_MD5`、`CC_SHA1` 或 CryptoKit `Insecure.MD5`/`Insecure.SHA1`。MASTG 演示：MASTG-DEMO-0015（CommonCrypto 破损哈希）、MASTG-DEMO-0016（CryptoKit 破损哈希）、MASTG-DEMO-0018（破损加密）。

### 合规：CryptoKit 加密

规范完整往返模式在 `cryptokit-symmetric.md` 和 `common-anti-patterns.md` 反模式 #6 中。此合规代码片段保持最小以避免重复规范加密指导。

```swift
import CryptoKit

enum CryptoError: Error { case invalidCiphertext }

/// 合规：OWASP M10（加密不足）、MASVS-CRYPTO-1。
/// 测试案例：MASTG-TEST-0210、MASTG-TEST-0317。iOS 13.0+。
func sealForStorage(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    guard let combined = sealedBox.combined else { throw CryptoError.invalidCiphertext }
    return combined
}

// 合规：MASVS-CRYPTO-2、MASTG-TEST-0213
let encryptionKey = SymmetricKey(size: .bits256) // 来自 CSPRNG 的 256 位
```

### 反模式：不安全加密

```swift
// ❌ 错误——MD5（碰撞可轻松构造）——未通过 MASTG-TEST-0211
var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
CC_MD5(data.bytes, CC_LONG(data.count), &digest)

// ❌ 错误——ECB 模式——未通过 MASTG-TEST-0317
CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionECBMode), key, keyLength, nil, plaintext, ...)

// ❌ 错误——不安全 RNG——未通过 MASTG-TEST-0311
let seed = srand(UInt32(time(nil)))  // 可预测种子

// ❌ 错误——硬编码密钥——未通过 MASTG-TEST-0213
let key = SymmetricKey(data: "my-secret-key-1234567890123456".data(using: .utf8)!)

// ❌ 错误——静态 nonce（重用时灾难性）
let nonce = try AES.GCM.Nonce(data: Data(repeating: 0, count: 12))
let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
```

---

## kSecAttrAccessible 选择指南

> 完整选择标准和数据保护层级映射：`keychain-access-control.md` § "何时"层：七个可访问性常量。以下指导是审计上下文的合规性快速参考。

Keychain 可访问性是最重要的 iOS 安全决策——它同时解决 M1、M3、M9 和 M10 要求。

| 常量                                               | 备份 | iCloud | 需要密码               | 用于                                               |
| -------------------------------------------------- | ---- | ------ | ---------------------- | -------------------------------------------------- |
| `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`  | ❌   | ❌     | ✅（移除时删除）       | **最高敏感度：认证令牌、加密密钥**                 |
| `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`     | ❌   | ❌     | ❌                      | 敏感数据，设备特定                                 |
| `kSecAttrAccessibleWhenUnlocked`（默认）           | ✅   | ✅     | ❌                      | 需要同步的通用凭据                                 |
| `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | ❌   | ❌     | ❌                      | 后台可访问，设备特定                               |
| `kSecAttrAccessibleAfterFirstUnlock`               | ✅   | ✅     | ❌                      | 后台任务（如推送通知密钥）                         |
| `kSecAttrAccessibleAlways`                         | ✅   | ✅     | ❌                      | **❌ 废弃 (iOS 12)——永不使用**                     |

**关键：** `kSecAttrAccessible` 和 `kSecAttrAccessControl` 互斥。使用 `SecAccessControlCreateWithFlags` 时，可访问性级别是函数的第一个参数——不要在查询字典中也设置 `kSecAttrAccessible`，否则会得到 `errSecParam (-50)`。见 `keychain-access-control.md`。

> **交叉验证说明：** 并行研究来源推荐 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 作为标准；Claude 来源推荐 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`。两者都有效。`WhenPasscodeSet` 变体严格更安全（移除密码时删除条目）但可能让用户惊讶。根据威胁模型选择：高安全性凭据用 `WhenPasscodeSet`，通用敏感数据用 `WhenUnlocked`。

---

## 企业审计工作流

### 安全团队如何评估 iOS App

审计员根据 MAS Testing Profiles 评估：低风险 App 用 **L1（标准）**，处理财务、健康或高度敏感数据的 App 用 **L2（深度防御）**——要求 Keychain 管理的加密、硬件绑定的生物识别和证书锁定。

**审计工具工作流：** (1) 静态分析——MobSF 用于自动扫描；radare2 用于定向 API 分析。(2) 动态分析——objection 用于 keychain 转储（`ios keychain dump`）、文件保护验证、UserDefaults 检查（`ios nsuserdefaults get`）、生物识别绕过（`ios ui biometrics_bypass`）。(3) 网络——Burp Suite 带 objection SSL 锁定绕过。(4) 二进制——class-dump/dsdump 用于方法枚举。

**审计员目标的关键文件系统路径：** `<Sandbox>/Library/Preferences/<BundleID>.plist`（UserDefaults）、`<Sandbox>/Documents/`（数据库）、`<Sandbox>/Library/Caches/`（Web 缓存）、`<Sandbox>/Library/SplashBoard/Snapshots/`（截图缓存）、`<Sandbox>/tmp/`（带未清除数据的临时文件）。

### 前 10 审计发现

| 排名 | 发现                         | OWASP  | MASVS        | MASTG 测试  | 严重程度 |
| ---- | ---------------------------- | ------ | ------------ | ----------- | -------- |
| 1    | UserDefaults/plist 中的密钥  | M1, M9 | STORAGE-1    | 0299, 0302  | Critical |
| 2    | 仅 LAContext 生物识别认证    | M3     | AUTH-2       | 0266, 0267  | High     |
| 3    | 缺少证书锁定                 | M5     | NETWORK-2    | 0244        | High     |
| 4    | 二进制中硬编码 API 密钥      | M1     | CRYPTO-2     | 0213, 0214  | Critical |
| 5    | 废弃加密（MD5、DES）         | M10    | CRYPTO-1     | 0210, 0211  | High     |
| 6    | 不安全 keychain 可访问性     | M9     | STORAGE-1    | 0299        | Medium   |
| 7    | 日志中的敏感数据             | M9     | STORAGE-2    | 0296, 0297  | Medium   |
| 8    | 缺少越狱检测                 | M7     | RESILIENCE-1 | —           | Low      |
| 9    | 未加密 SQLite/Realm          | M9     | STORAGE-1    | 0302        | High     |
| 10   | ATS 例外允许 HTTP            | M5     | NETWORK-1    | —           | Medium   |

### 证据套件（5 个制品）

| 制品               | 证明                                        | OWASP/MASVS |
| ------------------ | ------------------------------------------- | ----------- |
| 静态分析报告       | 无硬编码密钥或弱加密                        | M1, M10     |
| 文件系统/xattr 日志| 应用了 `NSFileProtectionComplete`           | M9          |
| Keychain 转储      | 存在 `ThisDeviceOnly` + `SecAccessControl`  | M1, M9      |
| 备份提取           | 无敏感数据迁移                              | M9          |
| 代码片段           | 使用了正确 API 和标志                       | 所有        |

### 越狱时代测试（2025–2026）

截至 iOS 26，当前版本不存在可越狱设备。审计员使用非越狱技术：objection 带 Frida Gadget 注入到重新打包的 IPA、Corellium 虚拟设备，或 iMazing 进行备份提取。这使自动静态分析（MobSF、semgrep）和基于 Frida Gadget 的动态测试成为主要评估路径。

---

## 后量子密码学路线图

Apple 在 WWDC 2025（Session 314："Get ahead with quantum-secure cryptography"）宣布 PQC 支持。威胁模型："现在收集，以后解密"——对手今天收集加密流量用于未来量子解密。

| 日期                     | 里程碑                                                                             |
| ------------------------ | ---------------------------------------------------------------------------------- |
| 2024 年 2 月 (iOS 17.4)  | iMessage PQ3——首个大规模量子安全消息                                               |
| 2024 年 8 月             | NIST 最终确定 FIPS 203/204/205                                                     |
| 2025 年 1 月             | CISA 将不安全加密算法添加到坏实践列表                                              |
| 2025 年 6 月 (WWDC)      | 为 iOS 26 宣布 CryptoKit PQC API                                                   |
| 2025 年 9 月 (iOS 26)    | CryptoKit 中的 ML-KEM-768/1024、ML-DSA-65/87、X-Wing KEM；默认量子安全 TLS         |
| 2030（NIST 目标）        | 废弃经典公钥加密                                                                   |
| 2035（CNSA 2.0）         | 国家安全系统不允许经典算法                                                         |

Apple 使用混合密码学——结合后量子和经典算法，使更新永不将安全性降低到经典基线以下。现在构建加密敏捷性：在协议后抽象加密接口，以在 PQC 采用成为强制时允许配置级切换。见 `cryptokit-public-key.md` 了解 ML-KEM/ML-DSA 实现细节。

---

## 交叉引用索引

| iOS 实践                                                  | M1  | M3  | M9  | M10              | 主要参考                        |
| --------------------------------------------------------- | --- | --- | --- | ---------------- | ------------------------------- |
| Keychain + `WhenPasscodeSetThisDeviceOnly`                | ✅  | —   | ✅  | ✅（密钥存储）   | `keychain-access-control.md`    |
| `SecAccessControlCreateWithFlags` + `.biometryCurrentSet` | ✅  | ✅  | ✅  | —                | `biometric-authentication.md`   |
| 带自动 nonce 的 CryptoKit AES.GCM                         | —   | —   | ✅  | ✅               | `cryptokit-symmetric.md`        |
| `NSFileProtectionComplete`                                | —   | —   | ✅  | —                | `keychain-access-control.md`    |
| 用于密钥/令牌生成的 `SecRandomCopyBytes`                  | ✅  | ✅  | —   | ✅               | `cryptokit-symmetric.md`        |
| 用于凭据配置的 App Attest                                 | ✅  | ✅  | —   | —                | `credential-storage-patterns.md`|
| ML-KEM/ML-DSA (iOS 26+)                                   | —   | —   | —   | ✅               | `cryptokit-public-key.md`       |

---

## 结论

此映射出现三个模式。首先，Keychain 是 iOS 上的通用合规机制——一个正确配置的带 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` 和 `.biometryCurrentSet` 的 `SecItemAdd` 同时满足 M1、M3 和 M9。其次，任何对"M2：不安全数据存储"或"M5：加密不足"的引用都标记过时的 2016 指导。第三，MASTG 向新测试 ID（MASTG-TEST-02xx/03xx）的过渡意味着代码注释中的旧版 MSTG-\* 引用应更新。

对于 2025–2026，最重要的变化是后量子密码学到达生产 iOS。NIST 目标 2030 年废弃经典 PKC，Apple 在 iOS 26 中发布 ML-KEM/ML-DSA 并默认启用量子安全 TLS，合规项目现在应评估混合加密策略。

---

## 总结清单

1. **OWASP 2024 编号** —— 所有引用使用 2024 编号（M1/M3/M9/M10），而非 2016（M2/M5/M4+M6）
2. **MASTG 测试 ID** —— 引用使用新 MASTG-TEST-02xx/03xx ID（不仅旧版 MSTG-\*）
3. **仅 Keychain 凭据存储** —— 凭据存储在 Keychain 中带 `ThisDeviceOnly` 可访问性，永不在 UserDefaults/plist/文件中
4. **Keychain 绑定的生物识别** —— 认证使用 `SecAccessControlCreateWithFlags` + `.biometryCurrentSet`，而非仅 LAContext
5. **无双重访问控制** —— `kSecAttrAccessible` 和 `kSecAttrAccessControl` 永不在同一查询中同时设置
6. **CryptoKit 算法** —— 所有加密操作使用 CryptoKit (iOS 13+) 或 SecKey——无 CommonCrypto 废弃算法（MD5、DES、3DES、RC4、ECB）
7. **自动 nonce** —— AES-GCM 加密依赖 CryptoKit 自动 nonce；无手动 nonce 构造（无文档化轮换策略）
8. **文件保护** —— 敏感文件使用 `NSFileProtectionComplete` 并通过 `isExcludedFromBackup` 从备份排除
9. **无敏感日志** —— `NSLog`/`print` 语句或键盘缓存中无敏感数据（`.autocorrectionType = .no`、`.isSecureTextEntry = true`）
10. **合规注释** —— 代码注释包含 OWASP 类别、MASVS 控制和 MASTG 测试案例 ID
11. **后量子就绪** —— 加密接口在协议后抽象，启用未来 ML-KEM/ML-DSA 采用
