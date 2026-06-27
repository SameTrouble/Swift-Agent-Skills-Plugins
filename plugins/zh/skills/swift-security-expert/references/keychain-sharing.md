# Keychain 共享：访问组、扩展和跨设备同步

> 范围：跨 App 目标、扩展和设备共享 keychain 条目的访问组设计和权限正确性。

keychain 访问组是 Apple 平台上 App 和扩展间共享凭据的唯一机制。正确配置需要精确的 Team ID 前缀、按目标权限和代码中显式 `kSecAttrAccessGroup` 使用——三个要求大多数 AI 生成代码都搞错。本参考涵盖访问组机制、两种权限系统、正确和错误的 Swift 模式、macOS 特定要求、iCloud 同步、平台边缘情况和调试策略。所有指导反映截至 iOS 18、macOS Sequoia 15 和 2025–2026 开发者格局的当前行为。

**权威来源：** Apple "Sharing Access to Keychain Items Among a Collection of Apps" 文档、TN3137 "On Mac Keychain APIs and Implementations"、Apple Platform Security Guide（iCloud Keychain 同步）、Quinn "The Eskimo!" DTS 论坛帖子 "SecItem: Fundamentals" 和 "SecItem: Pitfalls and Best Practices"（2025 年 5 月更新）、Configuring Keychain Sharing 文档。

---

## 访问组如何工作

每个 App 属于一个或多个**访问组**——标记哪些进程可以读写特定 keychain 条目的字符串标识符。一个 App 可以属于多个组，但每个 keychain 条目属于**恰好一个**。`securityd` 守护进程通过在运行时检查调用进程的权限与条目的组来强制访问。

系统通过按**此确切顺序**连接三个来源为每个 App 构造虚拟访问组数组：

1. **来自 `keychain-access-groups` 权限的 keychain 访问组**
2. **应用标识符** —— 自动生成为 `TeamID.BundleID`（如 `SKMME9E2Y8.com.example.MyApp`）
3. **来自 `com.apple.security.application-groups` 权限的应用组** (iOS 8+)

**此连接列表中的第一项成为默认访问组。** 当调用 `SecItemAdd` 不指定 `kSecAttrAccessGroup` 时，条目落在该默认组中。当调用 `SecItemCopyMatching` 不指定组时，搜索跨 App 所属的**所有**组。此顺序意味着 keychain 访问组可以是默认（它出现在第一位），但应用组永不能是默认，因为应用标识符始终在其之前。

带一个 keychain 组和一个应用组的 App 示例：

```text
[SKMME9E2Y8.com.example.SharedItems,    ← keychain 访问组（默认）
 SKMME9E2Y8.com.example.MyApp,          ← 应用标识符（自动）
 group.com.example.AppSuite]             ← 应用组
```

**共享限于单个开发团队。** 来自不同开发者团队的 App 不能通过访问组共享 keychain 条目。每个组标识符上的 Team ID 前缀通过代码签名的配置文件强制，防止跨团队访问。不同开发者的 App 共享凭据的唯一方式是通过 iCloud Keychain + 关联域（基于 Web 域所有权的密码自动填充），这是完全不同的机制。

---

## 两种权限、两种格式、不同目的

最常见的开发者错误是**混淆 Keychain Sharing 与 App Groups**。这些是独立能力，带不同权限键、不同标识符格式和不同范围。

### Keychain Sharing（`keychain-access-groups`）

此权限仅为在 App 间共享 keychain 条目存在。标识符以 Team ID 为前缀：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.example.SharedItems</string>
    </array>
</dict>
</plist>
```

`$(AppIdentifierPrefix)` 构建变量在签名时解析为 Team ID 后跟点（如 `SKMME9E2Y8.`）。在代码中，需要完全解析的字符串——`"SKMME9E2Y8.com.example.SharedItems"`——而非仅 `"com.example.SharedItems"`。

### App Groups（`com.apple.security.application-groups`）

App Groups 共享的不仅是 keychain 条目：共享文件容器、`UserDefaults(suiteName:)` 和 IPC。标识符使用 `group.` 前缀且**无 Team ID**：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.example.AppSuite</string>
    </array>
</dict>
</plist>
```

自 iOS 8 起，应用组名兼作 keychain 访问组——`"group.com.example.AppSuite"` 可用作 `kSecAttrAccessGroup` 值。然而，应用组在访问组数组中最后出现且**永不能是新条目的默认组**。关键 macOS 注意：**应用组不能在 macOS 上用作 keychain 访问组**——这是仅 iOS/iPadOS 的功能。

### 比较表

| 方面                     | Keychain Sharing                           | App Groups                                                   |
| ------------------------ | ------------------------------------------ | ------------------------------------------------------------ |
| **权限键**               | `keychain-access-groups`                   | `com.apple.security.application-groups`                      |
| **格式**                 | `$(AppIdentifierPrefix)com.example.shared` | `group.com.example.shared`                                   |
| **Team ID 前缀**         | 是（通过构建变量自动）                     | 否（`group.` 前缀替代）                                      |
| **共享**                 | 仅 keychain 条目                           | 容器、UserDefaults、IPC 和 keychain 条目（仅 iOS）           |
| **可作为默认组**         | 是（如果数组中第一）                       | 否                                                           |
| **macOS keychain 共享**  | 是（带数据保护 keychain）                  | 否                                                           |

两种权限可同时使用。如果仅需要 keychain 共享，使用 Keychain Sharing。如果已为共享 UserDefaults 或文件容器使用 App Groups，它们可以在 iOS 上搭载用于 keychain 共享——但始终显式指定 `kSecAttrAccessGroup`。

---

## 代码模式：正确和错误

### 存储带显式访问组的条目

```swift
import Security

let teamID = "SKMME9E2Y8"
let accessGroup = "\(teamID).com.example.SharedItems"

let password = "s3cretT0ken".data(using: .utf8)!
let addQuery: [String: Any] = [
    kSecClass as String:            kSecClassGenericPassword,
    kSecAttrService as String:      "com.example.authService",
    kSecAttrAccount as String:      "user@example.com",
    kSecAttrAccessGroup as String:  accessGroup,
    kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    kSecValueData as String:        password
]

let status = SecItemAdd(addQuery as CFDictionary, nil)
guard status == errSecSuccess else {
    print("Keychain add failed: \(status)")  // -34018 = 缺少权限
    return
}
```

Team ID 必须是来自 Apple Developer 账户的**字面 10 字符字符串**，而非构建变量——`$(AppIdentifierPrefix)` 仅在权限 plist 中工作，不在 Swift 代码中。

### 无 Team ID 前缀的访问组（最常见 AI 错误）

```swift
// ❌ 错误——缺少 Team ID 前缀
let accessGroup = "com.example.SharedItems"

let addQuery: [String: Any] = [
    kSecClass as String:            kSecClassGenericPassword,
    kSecAttrService as String:      "com.example.authService",
    kSecAttrAccount as String:      "user@example.com",
    kSecAttrAccessGroup as String:  accessGroup,  // 将失败！
    kSecValueData as String:        password
]
// iOS 13+ 返回 errSecMissingEntitlement (-34018)
// 旧版本返回 errSecItemNotFound (-25300)
```

Xcode 的 Keychain Sharing UI 显示 `com.example.SharedItems` 不带前缀，这误导开发者和 AI 生成器。**在代码中，始终需要完整的 `TEAMID.com.example.SharedItems` 字符串。**

### App 扩展读取共享 keychain 条目

扩展目标必须有自己的 Keychain Sharing 能力带相同组：

```swift
// 在小部件扩展、共享扩展或其他 App 扩展中
let teamID = "SKMME9E2Y8"
let accessGroup = "\(teamID).com.example.SharedItems"

let readQuery: [String: Any] = [
    kSecClass as String:            kSecClassGenericPassword,
    kSecAttrService as String:      "com.example.authService",
    kSecAttrAccount as String:      "user@example.com",
    kSecAttrAccessGroup as String:  accessGroup,
    kSecReturnData as String:       true
]

var result: AnyObject?
let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
if status == errSecSuccess, let data = result as? Data {
    let token = String(data: data, encoding: .utf8)
    // 使用共享令牌
}
```

### 因缺少权限而失败的扩展

```swift
// ❌ 此代码语法正确，但扩展目标在 Xcode → Signing & Capabilities 中
// 缺少 Keychain Sharing 能力。
// 主 App 有它，但扩展是独立可执行目标。
// 结果：errSecMissingEntitlement (-34018)
```

**每个可执行目标——主 App、小部件扩展、共享扩展、通知扩展——需要自己的 Keychain Sharing 权限。** 框架没有权限；只有链接它们的目标有。在 Xcode 中：选择扩展目标 → Signing & Capabilities → + Capability → Keychain Sharing → 添加相同组名。

### 带 `kSecAttrSynchronizable` 的 iCloud Keychain 同步

```swift
let syncQuery: [String: Any] = [
    kSecClass as String:                kSecClassGenericPassword,
    kSecAttrService as String:          "com.example.authService",
    kSecAttrAccount as String:          "user@example.com",
    kSecAttrAccessGroup as String:      "\(teamID).com.example.SharedItems",
    kSecAttrSynchronizable as String:   kCFBooleanTrue!,
    kSecAttrAccessible as String:       kSecAttrAccessibleAfterFirstUnlock,
    kSecValueData as String:            password
]
let status = SecItemAdd(syncQuery as CFDictionary, nil)
```

**关键约束：**

- 可同步条目**不能**使用以 `ThisDeviceOnly` 结尾的 `kSecAttrAccessible` 值——条目永不同步。尝试此操作静默不同步跨设备。
- 查询可同步条目时，包含 `kSecAttrSynchronizable: true` 或 `kSecAttrSynchronizableAny`——否则搜索排除它们。
- 用户必须在所有目标设备上启用 iCloud Keychain 并登录相同 Apple ID。
- 同步与设备上共享正交：条目可以同时在共享访问组和跨设备可同步。

```swift
// ✅ 同时查找同步和非同步条目的查询
let findQuery: [String: Any] = [
    kSecClass as String:                kSecClassGenericPassword,
    kSecAttrService as String:          "com.example.authService",
    kSecAttrSynchronizable as String:   kSecAttrSynchronizableAny,
    kSecReturnData as String:           true
]
```

### 假设条目默认同步

```swift
// ❌ 错误——此条目不会同步到 iCloud Keychain。
// 省略时 kSecAttrSynchronizable 默认为 false。
let addQuery: [String: Any] = [
    kSecClass as String:       kSecClassGenericPassword,
    kSecAttrService as String: "com.example.authService",
    kSecAttrAccount as String: "user@example.com",
    kSecValueData as String:   password
    // 无 kSecAttrSynchronizable → 仅在此设备上存在
]
```

iCloud Keychain 同步是**严格按条目选择加入**。省略 `kSecAttrSynchronizable` 或设置为 `false` 意味着条目仅存在于当前设备。同步条目受益于端到端加密——Apple 无法解密数据。

---

## 跨目标权限设置

扩展是独立的沙盒可执行目标，**不**从其包含 App 继承能力。

### Xcode 配置步骤

1. 选择主应用目标 → Signing & Capabilities → + Capability → Keychain Sharing。
2. 添加所需组标识符（如 `com.example.shared`）。Xcode 在权限文件中自动加 Team ID 前缀。
3. **对每个扩展目标重复** ——选择扩展目标，添加 Keychain Sharing，添加**完全相同**的组标识符。
4. 对于 App Groups：为每个目标添加 App Groups 能力并使用相同 `group.` 标识符。

### 所需权限矩阵

| 目标                | `keychain-access-groups`    | `application-groups`         | 备注                                |
| ------------------- | --------------------------- | ---------------------------- | ----------------------------------- |
| **主 App**          | `TEAMID.com.example.shared` | `group.com.example.appsuite` | 第一项定义默认组                    |
| **共享扩展**        | `TEAMID.com.example.shared` | `group.com.example.appsuite` | 必须完全匹配                        |
| **小部件扩展**      | `TEAMID.com.example.shared` | `group.com.example.appsuite` | 独立签名和配置                      |
| **通知扩展**        | `TEAMID.com.example.shared` | `group.com.example.appsuite` | 相同规则适用                        |

---

## macOS Keychain 分裂

macOS 维护**两个完全独立的 keychain 实现**，混淆它们是无尽 bug 的来源。根据 Apple 的 TN3137：

**基于文件的 keychain** —— 可追溯到 Mac OS X 的遗留系统。使用访问控制列表（`SecAccess`），将条目存储在 `.keychain-db` 文件中，是 macOS 上 `SecItem` API 调用的默认目标。不支持 iCloud Keychain、生物识别、Secure Enclave 密钥或访问组。

**数据保护 keychain** —— 起源于 iOS，通过 iCloud Keychain 于 10.9 到达 macOS。使用 keychain 访问组 + `SecAccessControl`，支持 iCloud 同步、Touch ID/Face ID 和 Secure Enclave。仅在用户登录上下文中可用——**`launchd` 守护进程不能使用它**。

### 带 `kSecUseDataProtectionKeychain` 的跨平台 macOS 支持

```swift
var query: [String: Any] = [
    kSecClass as String:                        kSecClassGenericPassword,
    kSecAttrService as String:                  "com.example.authService",
    kSecAttrAccount as String:                  "user@example.com",
    kSecAttrAccessGroup as String:              "\(teamID).com.example.SharedItems",
    kSecUseDataProtectionKeychain as String:     true,
    kSecValueData as String:                     password
]
let status = SecItemAdd(query as CFDictionary, nil)
```

在 macOS 上，`kSecAttrAccessGroup` **被静默忽略**，除非以数据保护 keychain 为目标。设置 `kSecUseDataProtectionKeychain` 为 `true` 选择加入 iOS 风格的 keychain 行为。在 iOS、tvOS 和 watchOS 上此键被忽略（这些平台始终使用数据保护）。

在 macOS 上以数据保护 keychain 为目标的两种方式：设置 `kSecUseDataProtectionKeychain` 为 `true`，或设置 `kSecAttrSynchronizable` 为 `true`（同时也启用 iCloud 同步）。Mac Catalyst 和 iOS Apps on Mac 专门使用数据保护——标志在那里被忽略。

| 平台/运行时         | 默认 keychain        | 支持访问组       | 所需标志                         |
| ------------------- | -------------------- | ---------------- | -------------------------------- |
| **iOS/iPadOS**      | 数据保护             | 是               | 无                               |
| **Mac Catalyst**    | 数据保护             | 是               | 无                               |
| **macOS (AppKit)**  | 遗留基于文件         | 否（默认）       | `kSecUseDataProtectionKeychain: true` |

Apple 的 TN3137 指出基于文件的 keychain **"正在废弃路径上。"** `SecKeychainCreate` 在 macOS 12 SDK 中废弃。新代码应专门以数据保护为目标，唯一例外是缺乏用户上下文的 `launchd` 守护进程。

---

## 在访问组间迁移条目

`kSecAttrAccessGroup` 对现有 keychain 条目**不可变**——不能通过 `SecItemUpdate` 更改。迁移需要 read-add-delete 序列：

1. **读取**：通过 `SecItemCopyMatching` 从其原始访问组检索完整条目。
2. **添加**：带新 `kSecAttrAccessGroup` 调用 `SecItemAdd`。
3. **删除**：仅在 `SecItemAdd` 返回 `errSecSuccess` 后，通过 `SecItemDelete` 删除原始条目。

如果添加操作失败，原始条目保持不变，防止数据丢失。此模式安全，因为它在新副本确认后才删除。

---

## 生命周期边缘情况

### keychain 条目在 App 卸载后持久

此行为未文档记录但自 iOS 早期就一致。Apple 在 iOS 10.3 beta 中尝试在 App 移除时删除 keychain 条目，但因兼容性问题在发布前回滚。Quinn "The Eskimo!" 警告此行为**可能随时更改而无通知**。如果共享 keychain 条目存在于 App A 和 App B 之间，删除 App A 将所有共享条目完整保留给 App B。即使删除共享组中的所有 App 也不移除孤立条目——仅恢复出厂设置可靠清除它们。

检测全新安装的常见变通方法（因为 `UserDefaults` 在卸载时_被_清除）：

```swift
func clearKeychainOnFreshInstall() {
    let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    if !hasLaunchedBefore {
        // 将删除范围限制到特定 service/group 以避免核弹式清除共享条目
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.example.authService"
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
    }
}
```

> 完整版本化迁移方法和全新安装检测模式，见 `migration-legacy-stores.md` § 首次启动 Keychain 清理。
> 关键点：上面的模式处理基本共享上下文情况；规范文件涵盖多版本迁移协调、安全删除排序和 CI 影响。

### 团队间 App 转移破坏 keychain 访问

条目绑定到原始 Team ID。如果 App 转移到另一个开发者账户，存储在旧 Team ID 下的 keychain 条目变得不可访问。推荐变通方法：转移 App 回来，发布导出/迁移 keychain 数据到外部存储的更新，然后再转移。

### 跨开发者共享通过访问组不可能

Team ID 前缀强制通过代码签名的配置文件，防止不同团队的 App 访问彼此的 keychain 条目。跨开发者凭据共享需要 iCloud Keychain + 关联域（基于 Web 域所有权的密码自动填充）。

---

## 平台特定模式

### watchOS

watchOS 2+ 运行**独立 keychain**，不通过访问组连接到配对 iPhone 的 keychain。在 iPhone 和 Watch 间共享凭据需要 iCloud Keychain 同步（`kSecAttrSynchronizable: true`，watchOS 6.2 起可用）或 WatchConnectivity 数据传输。对于 watchOS App，将 Keychain Sharing 添加到 **WatchKit Extension 目标**，而非 WatchKit App 目标。

### 小部件扩展（WidgetKit）

小部件扩展遵循与所有 App 扩展相同的规则——独立将 Keychain Sharing 或 App Groups 能力添加到小部件扩展目标。小部件通常需要认证令牌用于网络请求。将这些存储在共享 keychain 组中而非 `UserDefaults(suiteName:)`，后者缺乏 keychain 级加密。应用组共享容器仅使用标准文件系统加密（`NSFileProtectionCompleteUntilFirstUserAuthentication`），使 keychain 成为敏感凭据的更安全选择。

---

## 构建和分发考虑

权限格式和 Team ID 前缀规则在所有构建配置中一致：开发、Ad Hoc、TestFlight 和 App Store 分发。Team ID 是开发者账户固有的，不在配置间变化。

然而，每种分发类型的特定**配置文件**决定允许哪些权限并嵌入正确的 `AppIdentifierPrefix`。验证每种构建类型的配置文件正确授权所需访问组。

**遗留账户注意：** 大多数现代账户使用 Team ID 作为 App ID 前缀，但遗留账户（2011 年 6 月前）可能有与 Team ID 不同的每 App 前缀。报告称向一个目标而非另一个添加能力（如关联域）会更改前缀，导致 `-34018` 错误。确保所有共享 keychain 组的目标有相同能力。

---

## 调试 Keychain 共享中断

### 关键错误码

| 代码       | 常量                          | 含义                                                          |
| ---------- | ----------------------------- | ------------------------------------------------------------- |
| **0**      | `errSecSuccess`               | 操作成功                                                      |
| **-25299** | `errSecDuplicateItem`         | 条目存在；改用 `SecItemUpdate`                                |
| **-25300** | `errSecItemNotFound`          | 未找到匹配；iOS 13 前也返回用于未授权组                       |
| **-34018** | `errSecMissingEntitlement`    | App 缺少指定访问组的权限                                      |
| **-25308** | `errSecInteractionNotAllowed` | 设备锁定且条目需要 `WhenUnlocked` 访问                        |
| **-50**    | `errSecParam`                 | 无效参数（缺少 `kSecClass`、错误值类型）                      |

从 **iOS 13** 起，查询未授权访问组返回显式 `errSecMissingEntitlement` (-34018) 而非模糊的 `errSecItemNotFound`。这使现代 OS 版本上调试显著更容易。

### 调试清单

**1. 验证构建二进制上的权限** —— 而非 `.entitlements` 源文件：

```bash
codesign -d --entitlements :- /path/to/YourApp.app
codesign -d --entitlements :- /path/to/YourExtension.appex
```

比较 `keychain-access-groups` 数组——它们必须包含共同组。

**2. 检查配置文件：**

```bash
security cms -D -i YourApp.app/embedded.mobileprovision
```

验证 `keychain-access-groups`、`com.apple.security.application-groups` 和 `com.apple.developer.team-identifier` 存在且正确。

**3. 在物理设备上测试。** iOS Simulator 不使用真实配置文件，可能不暴露权限问题。Simulator 中的 Keychain Sharing 行为可能与设备行为不同。

**4. 监控系统日志。** 打开 Console.app，选择连接的设备，过滤"keychain"，重现问题。权限检查失败时系统记录显式消息，标识缺失组。

**5. 检查所有共享目标间的 App ID 前缀不匹配** —— 特别是如果任何目标启用了不同能力。

### 测试矩阵

| 场景                                   | 主 App | 共享扩展 | 小部件扩展 | 预期                                  |
| -------------------------------------- | :----: | :-------: | :--------: | ------------------------------------- |
| 在 `TeamID.com.example.shared` 中写/读 |   通过 |   通过    |    通过    | 所有目标看到相同条目                  |
| 在 `group.com.example.appsuite` 中写/读|   通过 |   通过    |    通过    | 仅当指定 `kSecAttrAccessGroup` 时     |
| iCloud 同步（非 `ThisDeviceOnly`）     |   通过 |    N/A    |    N/A     | 条目出现在第二设备                    |
| 扩展中缺少权限                         |   N/A  |   失败    |    N/A     | `-34018` 或 `-25300`                  |

---

## 安全威胁模型说明

- **端到端加密：** 同步的 iCloud Keychain 条目端到端加密；Apple 无法解密。
- **恶意设备风险：** 加入用户 iCloud 账户的设备可能访问或毒化同步 keychain 条目。始终最小范围密钥并验证从共享或同步 keychain 检索的数据。
- **过度共享风险：** 放在共享访问组中的条目可被该组中所有 App 读取。使用最窄可能的访问组——不要在不需要相同凭据的 App 间共享访问组。
- **孤立条目：** 共享组中所有 App 卸载后，keychain 条目在设备上保留直到恢复出厂设置。存储高度敏感数据时考虑此点。

---

## 2024–2026 变化

核心 `SecItem` API **未变化**。iOS 17、18 或 macOS 14/15 中未引入新的 keychain 共享特定 API。Apple 仍未发布 Swift 原生 keychain 包装器；基于 C 的 Security framework 仍是唯一官方接口。

iOS 18 和 macOS Sequoia（WWDC 2024）引入的 **Passwords App** 提供专用的用户界面管理密码、passkey 和验证码。这是 iCloud Keychain 上的 UI 层——不影响 `SecItem` API 或访问组机制。

**Passkey 增强**持续通过 WWDC 2024–2025，包括自动 passkey 升级和凭据导入/导出 API（`ASCredentialExportManager`）。这些在凭据管理器级别操作，不引入新的 keychain 共享机制。

`kSecAttrAccessibleAlways` 和 `kSecAttrAccessibleAlwaysThisDeviceOnly` 自 iOS 12 起仍废弃。使用 `kSecAttrAccessibleAfterFirstUnlock` 或更严格的 `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`。

---

## 交叉引用

- `keychain-fundamentals.md` —— SecItem CRUD 模式、macOS 上的 `kSecUseDataProtectionKeychain`、查询字典构造
- `keychain-access-control.md` —— 共享条目的可访问性常量、`ThisDeviceOnly` vs 可同步影响
- `keychain-item-classes.md` —— 复合主键和 `kSecAttrAccessGroup` 如何与每个 `kSecClass` 交互
- `common-anti-patterns.md` —— 反模式 #5（缺少 `kSecAttrAccessible`），在共享上下文中更复杂
- `credential-storage-patterns.md` —— App 和扩展间的 OAuth 令牌共享

---

## 结论

Apple 平台上的 keychain 共享是精确的、权限驱动的系统，其中小的配置错误——缺少 Team ID 前缀、未添加到扩展目标的能力、macOS 上遗忘的 `kSecUseDataProtectionKeychain`——产生无运行时警告的晦涩错误。访问组数组的三源连接顺序以让开发者措手不及的方式决定默认和搜索范围。

三条规则防止大多数问题：在代码中始终包含完整 Team ID 前缀（`TEAMID.com.example.shared`，绝不仅 `com.example.shared`）；将 Keychain Sharing 添加到每个需要访问的可执行目标，而非仅主 App；在 macOS 上设置 `kSecUseDataProtectionKeychain` 为 `true` 以获得 iOS 一致行为。对于 iCloud 同步，记住 `kSecAttrSynchronizable` 默认为 `false`，查询必须显式选择加入以查找可同步条目。

---

## 总结清单

1. **代码中 Team ID 前缀** —— Swift 中访问组字符串必须使用完全解析的 `TEAMID.com.example.shared` 格式；`$(AppIdentifierPrefix)` 仅在权限 plist 中工作。
2. **按目标权限** —— 每个可执行目标（主 App、每个扩展）必须在 Xcode 中独立添加 Keychain Sharing 能力带相同组标识符。
3. **Keychain Sharing vs App Groups** —— 这些是独立权限带不同格式（`keychain-access-groups` 带 Team ID 前缀 vs `com.apple.security.application-groups` 带 `group.` 前缀）。App Groups 在 macOS 上不能用作 keychain 访问组。
4. **默认访问组意识** —— 连接访问组数组中的第一项（keychain 组 → 应用标识符 → 应用组）成为默认。App Groups 永不能成为默认。
5. **显式 `kSecAttrAccessGroup`** —— 始终在 `SecItemAdd` 和 `SecItemCopyMatching` 调用中指定访问组。添加时省略使用默认组（可能意外）；查询时省略搜索所有组（可能慢或过于宽泛）。
6. **iCloud 同步是选择加入** —— `kSecAttrSynchronizable` 默认为 `false`。同步需要非 `ThisDeviceOnly` 可访问性，查询必须包含 `kSecAttrSynchronizable: true` 或 `kSecAttrSynchronizableAny` 以查找同步条目。
7. **macOS 数据保护 keychain** —— 在所有 macOS `SecItem` 调用上设置 `kSecUseDataProtectionKeychain: true`。没有它，`kSecAttrAccessGroup` 被静默忽略，使用遗留基于文件的 keychain。
8. **条目卸载后持久** —— Keychain 条目在 App 删除后存活。使用 `UserDefaults` 标志检测全新安装并清理陈旧条目。仔细范围删除以避免核弹式清除共享条目。
9. **`kSecAttrAccessGroup` 不可变** —— 在组间移动条目需要 read-add-delete 序列，而非更新。
10. **验证构建二进制权限** —— 对构建的 `.app`/`.appex` 使用 `codesign -d --entitlements :-` 确认权限，而非源 `.entitlements` 文件。在物理设备上测试；Simulator 可能不暴露权限问题。
11. **watchOS 隔离** —— Apple Watch 有独立 keychain，不通过访问组连接。使用 iCloud Keychain 同步或 WatchConnectivity 进行跨设备凭据共享。
