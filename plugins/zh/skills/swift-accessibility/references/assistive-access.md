# Assistive Access

Assive Access 是 iOS/iPadOS 17+ 的功能，为智力障碍人士提供认知简化的系统体验。应用可以提供专门的、精简的场景，带有大控件、视觉替代方案和降低的认知负担。

## 目录
- [什么是 Assistive Access](#什么是-assistive-access)
- [Info.plist 配置](#infoplist-配置)
- [SwiftUI 场景设置](#swiftui-场景设置)
- [UIKit 场景设置](#uikit-场景设置)
- [运行时检测](#运行时检测)
- [导航图标](#导航图标)
- [设计原则](#设计原则)
- [原生控件适配](#原生控件适配)
- [测试](#测试)
- [与其他无障碍功能结合](#与其他无障碍功能结合)
- [常见错误](#常见错误)

---

## 什么是 Assistive Access

Assistive Access 用简化的启动器和应用体验替换标准 iOS UI。关键特征：
- 大而清晰的控件，间距充裕
- 应用图标的网格或行布局
- 精简导航（无应用切换器、无控制中心滑动）
- 全程文字的视觉替代方案
- 减少干扰和更少选项
- 面向护理人员和使用认知障碍的用户一起配置设备

当你的应用声明支持 Assistive Access 时，它会出现在 Settings 的**Optimized Apps**列表中，并在用户点击其图标时使用你的专用场景启动。

---

## Info.plist 配置

### 标准支持

声明你的应用支持 Assistive Access。系统在 Assistive Access 模式下启动时显示单独的场景（你的 `AssistiveAccess` 场景）。

```xml
<key>UISupportsAssistiveAccess</key>
<true/>
```

### 全屏（可选）

对于已为认知无障碍设计的应用（AAC 应用、专业工具）。应用以其正常界面全屏显示，而非缩减的框架。

```xml
<key>UISupportsFullScreenInAssistiveAccess</key>
<true/>
```

仅当你的标准应用 UI 已适合 Assistive Access 用户时使用此键。它绕过单独场景机制。

---

## SwiftUI 场景设置

在主 `WindowGroup` 旁添加专用 `AssistiveAccess` 场景。当用户在 Assistive Access 模式下启动应用时，系统自动激活此场景。

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        // 标准应用界面
        WindowGroup {
            ContentView()
        }

        // 专用 Assistive Access 界面
        AssistiveAccess {
            AssistiveAccessContentView()
        }
    }
}
```

### Assistive Access 内容视图

为清晰、大目标和仅基本功能而设计：

```swift
struct AssistiveAccessContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Send Message") {
                    ComposeMessageView()
                }

                NavigationLink("Read Messages") {
                    InboxView()
                }

                NavigationLink("Contacts") {
                    ContactsView()
                }
                // ✅ 仅最基本的功能
                // ❌ 不包含设置、高级过滤器或次要操作
            }
            .navigationTitle("Messages")
            .assistiveAccessNavigationIcon(systemImage: "message.fill")
        }
    }
}
```

---

## UIKit 场景设置

对于 UIKit 应用，将 `UIHostingSceneDelegate` 与 SwiftUI `AssistiveAccess` 场景结合。

### 场景委托

```swift
import UIKit
import SwiftUI

class AssistiveAccessSceneDelegate: UIHostingSceneDelegate {
    static var rootScene: some Scene {
        AssistiveAccess {
            AssistiveAccessContentView()
        }
    }
}
```

### AppDelegate 配置

```swift
import UIKit

@main
class AppDelegate: UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        let config = UISceneConfiguration(name: nil, sessionRole: role)

        // 将 Assistive Access 会话路由到专用委托
        if role == .windowAssistiveAccessApplication {
            config.delegateClass = AssistiveAccessSceneDelegate.self
        }

        return config
    }
}
```

---

## 运行时检测

编程式检测 Assistive Access 以在共享组件内适配行为。

Assistive Access 功能在 iOS/iPadOS 17+ 上可用，但 SwiftUI 环境值 `accessibilityAssistiveAccessEnabled` 在 iOS/iPadOS 18+ 上可用。
对于 iOS/iPadOS 17，优先使用专用 `AssistiveAccess` 场景，避免共享视图分支，除非你提供自己的回退。

### SwiftUI

```swift
struct MessageRow: View {
    @Environment(\.accessibilityAssistiveAccessEnabled) private var assistiveAccessEnabled
    var message: Message

    var body: some View {
        HStack {
            // 在 Assistive Access 中显示头像图片（文字的视觉替代）
            if assistiveAccessEnabled {
                ContactAvatar(contact: message.sender, size: 60)
            }
            VStack(alignment: .leading) {
                Text(message.sender.name)
                    .font(assistiveAccessEnabled ? .title2 : .headline)
                Text(message.preview)
                    .font(assistiveAccessEnabled ? .body : .callout)
                    .lineLimit(assistiveAccessEnabled ? 3 : 2)
            }
        }
        .padding(assistiveAccessEnabled ? 16 : 12)
    }
}
```

如果你支持 iOS/iPadOS 17，为该环境值添加守卫：

```swift
struct MessageRow: View {
    var message: Message

    var body: some View {
        if #available(iOS 18, iPadOS 18, *) {
            MessageRowContent(message: message)
        } else {
            LegacyMessageRowContent(message: message)
        }
    }
}

@available(iOS 18, iPadOS 18, *)
private struct MessageRowContent: View {
    @Environment(\.accessibilityAssistiveAccessEnabled) private var assistiveAccessEnabled
    let message: Message

    var body: some View {
        HStack {
            if assistiveAccessEnabled {
                ContactAvatar(contact: message.sender, size: 60)
            }
            VStack(alignment: .leading) {
                Text(message.sender.name)
                    .font(assistiveAccessEnabled ? .title2 : .headline)
                Text(message.preview)
                    .font(assistiveAccessEnabled ? .body : .callout)
                    .lineLimit(assistiveAccessEnabled ? 3 : 2)
            }
        }
        .padding(assistiveAccessEnabled ? 16 : 12)
    }
}

private struct LegacyMessageRowContent: View {
    let message: Message

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(message.sender.name)
                    .font(.headline)
                Text(message.preview)
                    .font(.callout)
                    .lineLimit(2)
            }
        }
        .padding(12)
    }
}
```

### 谨慎使用

优先提供完全独立的 `AssistiveAccess` 场景，而非在共享视图中到处分支 `assistiveAccessEnabled`。检测最适合需要轻微适配的共享组件。

---

## 导航图标

Assistive Access 使用带大图标的网格或行启动器。为所有可导航视图添加导航图标：

```swift
// 系统 SF Symbol
.assistiveAccessNavigationIcon(systemImage: "star.fill")

// Assets 中的自定义图片
.assistiveAccessNavigationIcon(Image("my-feature-icon"))
```

图标出现在 Assistive Access 启动器网格中。使用清晰、可识别的符号，无需文字即可传达含义。

```swift
struct AssistiveAccessContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Messages") { MessagesView() }
                NavigationLink("Photos") { PhotosView() }
                NavigationLink("Music") { MusicView() }
            }
            .navigationTitle("My App")
            .assistiveAccessNavigationIcon(systemImage: "house.fill")  // 顶层图标
        }
    }
}

struct MessagesView: View {
    var body: some View {
        // ...
        List { /* messages */ }
            .navigationTitle("Messages")
            .assistiveAccessNavigationIcon(systemImage: "message.fill")
    }
}
```

---

## 设计原则

### 1. 提炼到核心功能

仅包含 1-3 个基本功能。移除设置、高级选项、过滤器以及护理人员会配置而非主要用户配置的任何内容。

```swift
// ❌ 对 Assistive Access 来说选项太多
List {
    NavigationLink("Inbox") { InboxView() }
    NavigationLink("Sent") { SentView() }
    NavigationLink("Drafts") { DraftsView() }
    NavigationLink("Spam") { SpamView() }
    NavigationLink("Trash") { TrashView() }
    NavigationLink("Settings") { SettingsView() }
    NavigationLink("Manage Accounts") { AccountsView() }
}

// ✅ 仅基本功能
List {
    NavigationLink("Read Messages") { InboxView() }
    NavigationLink("Send Message") { ComposeView() }
}
```

### 2. 大而清晰的控件

每个交互元素最小应为 60×60pt（超过标准 44pt 最小值）：

```swift
Button("Send") { send() }
    .font(.title2)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .background(Color.accentColor)
    .foregroundStyle(.white)
    .clipShape(RoundedRectangle(cornerRadius: 12))
```

### 3. 多重表示

结合文字 + 图标 + 颜色。永远不要仅依赖文字：

```swift
// ✅ 文字 + 图标
Label("New Message", systemImage: "square.and.pencil")
    .font(.title2)

// ✅ 带照片 + 姓名的联系人
HStack {
    ContactAvatar(contact: contact, size: 56)
    Text(contact.name).font(.title3)
}
```

### 4. 直观导航

- 每个屏幕上有清晰的返回按钮
- 逐步流程（每屏一个决策）
- 无隐藏手势或滑动导航
- 跨屏幕一致的按钮位置

### 5. 安全交互

- 为不可逆操作添加确认对话框
- 从主流程中移除危险操作
- 为每个操作提供撤销或取消

```swift
// ✅ 破坏性操作的确认
Button("Delete Message", role: .destructive) {
    showDeleteConfirm = true
}
.confirmationDialog("Delete this message?", isPresented: $showDeleteConfirm) {
    Button("Delete", role: .destructive) { delete() }
    Button("Cancel", role: .cancel) { }
}
```

---

## 原生控件适配

在 `AssistiveAccess` 场景中使用标准 SwiftUI 控件时，它们自动采用 Assistive Access 视觉风格：

- 按钮显示更大、文字更粗
- 列表使用突出的行分隔符
- 导航标题更突出
- 整体外观匹配 Assistive Access 系统应用

原生控件**无需额外样式代码**。自定义视图需要显式适配。

---

## 测试

### SwiftUI Preview

```swift
#Preview(traits: .assistiveAccess) {
    AssistiveAccessContentView()
}
```

### 在设备上

1. 启用 Assistive Access：Settings → Accessibility → Assistive Access → Set Up Assistive Access
2. 验证你的应用出现在"Optimized Apps"中（需要 Info.plist 中的 `UISupportsAssistiveAccess`）
3. 将你的应用添加到 Assistive Access 主屏幕
4. 在 Assistive Access 模式下测试所有用户流程
5. 关闭 Assistive Access：三击侧边按钮 → 输入密码

### 清单

- [ ] 应用出现在 Assistive Access 设置中的"Optimized Apps"
- [ ] 所有基本任务无需阅读能力即可完成（图标 + 文字或仅图标）
- [ ] 所有交互目标 ≥ 60pt
- [ ] 主要任务无需手势
- [ ] 破坏性操作需要确认
- [ ] 所有顶层目标定义了导航图标
- [ ] 主流程可完成且不会到达死胡同

---

## 与其他无障碍功能结合

Assistive Access 与 VoiceOver、Voice Control 和 Switch Control 兼容。用户可能同时激活多个功能。

设计 Assistive Access 场景时：
- 为所有元素使用语义标签（`accessibilityLabel`）（VoiceOver 兼容性）
- 确保按钮是 `Button` 类型或有 `.button` 特质（Voice Control 可见性）
- 避免限时交互（Switch Control 兼容性）
- 保持触摸目标 ≥ 44pt 最小值（标准无障碍）——目标 60pt+

---

## 常见错误

| 错误 | 修复 |
|---|---|
| `AssistiveAccess` 场景与标准场景 UI 相同 | 创建真正简化的界面，功能更少 |
| 缺少 `UISupportsAssistiveAccess` 键 | 添加到 Info.plist——出现在 Optimized Apps 中必需 |
| AA 场景中触摸目标低于 44pt | Assistive Access 使用最小 60pt；标准控件自动适配 |
| 主要任务需要手势 | 用显式按钮替换 |
| 无导航图标 | 添加 `.assistiveAccessNavigationIcon(systemImage:)` |
| 到处分支 `assistiveAccessEnabled` | 使用单独场景——更清晰、更可维护 |
| 破坏性操作无确认 | 用 `.confirmationDialog` 包装 |
| 仅文字控件无图标 | 添加带图片的 `Label` 或附加 `Image` |
