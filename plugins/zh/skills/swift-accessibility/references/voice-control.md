# Voice Control

Voice Control 让用户仅通过语音命令导航和与应用交互。它与 VoiceOver 不同——它面向有**运动障碍**但能看见屏幕却无法可靠使用双手的用户。

## 目录
- [Voice Control 的工作原理](#voice-control-的工作原理)
- [输入标签 - 核心 API](#输入标签---核心-api)
- ["Show Numbers" 和 "Show Names" 覆盖层](#show-numbers-和-show-names-覆盖层)
- [自定义操作](#自定义操作)
- [文字输入和编辑](#文字输入和编辑)
- [滚动和手势](#滚动和手势)
- [SiriKit 和 App Intents](#sirikit-和-app-intents)
- [测试清单](#测试清单)
- [常见失败](#常见失败)

---

## Voice Control 的工作原理

当用户说"Show numbers"时，每个交互元素都会收到一个编号覆盖层。"Tap 5"激活第 5 号元素。"Show names"显示文字标签。"Tap Send"激活标为"Send"的按钮。

**关键规则：** Voice Control 用于识别元素的标签必须精确匹配用户在屏幕上看到的内容。UI 中显示"Send"但 `accessibilityLabel` 为"Submit"的按钮，当用户说"Tap Send"时会静默失败。

Voice Control 使用此解析顺序：
1. 元素的可见文字
2. `accessibilityInputLabels`（第一个条目）
3. `accessibilityLabel`

如果可见文字和 `accessibilityLabel` 不匹配，Voice Control 无法在没有 `accessibilityInputLabels` 的情况下调和它们。

---

## 输入标签 - 核心 API

### SwiftUI: `.accessibilityInputLabels(_:)`

提供 Voice Control（和 Siri）可用于激活元素的备选名称。如果未设置单独标签，**第一个条目**也用作默认 `accessibilityLabel`。

```swift
// 仅图标按钮——无可见文字，VoiceOver 需要标签，Voice Control 需要名称
Button { composeMessage() } label: {
    Image(systemName: "square.and.pencil")
}
.accessibilityLabel("Compose")           // VoiceOver 标签
.accessibilityInputLabels(["Compose", "New Message", "Write"])  // Voice Control 名称

// 缩写的可见文字——用户可能说出完整短语
Button("DL Report") { downloadReport() }
    .accessibilityInputLabels(["Download Report", "DL Report", "Export Report"])

// 可见文字明确时——不需要输入标签
Button("Send") { send() }  // "Tap Send" 直接可用
```

**顺序很重要：** 从最具体到最不具体列出名称。Voice Control 使用第一个匹配。

### UIKit: `accessibilityUserInputLabels`

```swift
button.accessibilityLabel = "Compose"
button.accessibilityUserInputLabels = ["Compose", "New Message", "Write"]
```

### 何时添加输入标签

| 情形 | 操作 |
|---|---|
| 仅图标按钮 | 始终添加匹配操作的输入标签 |
| 缩写的可见文字（"Msg"、"DL"、"Fav"） | 添加完整单词备选 |
| 可见文字匹配 accessibilityLabel | 不需要 |
| 可见文字与 accessibilityLabel 不同 | 必需——或重写 accessibilityLabel 使其匹配 |
| 多个相同可见文字的按钮 | 添加唯一的区分标签 |

---

## "Show Numbers" 和 "Show Names" 覆盖层

当 Voice Control 显示覆盖层时，每个**交互**元素都必须出现。

### 元素为什么缺失

如果满足以下条件，元素对 Voice Control 不可见：
- `isAccessibilityElement = false`（UIKit）或 `.accessibilityHidden(true)`（SwiftUI）
- 元素是无无障碍信息的自定义视图
- 元素无标签且不被识别为交互元素
- 元素使用自定义点击处理（`.onTapGesture`）而无适当的可访问包装

### 使自定义可点击视图可发现

```swift
// ❌ onTapGesture 不向 Voice Control 注册为交互元素
Image(systemName: "heart")
    .onTapGesture { toggleFavorite() }

// ✅ Button 始终被 Voice Control 发现
Button { toggleFavorite() } label: {
    Image(systemName: "heart")
}
.accessibilityLabel("Favorite")

// ✅ UIKit 等价——确保 isAccessibilityElement = true 并设置特质
let heartView = HeartView()
heartView.isAccessibilityElement = true
heartView.accessibilityTraits = .button
heartView.accessibilityLabel = "Favorite"
```

### 多个相同标签

如果两个元素同名，Voice Control 显示消歧（"Which 'Delete'?"）要求用户点击数字。优先使用唯一标签。

```swift
// ❌ 三个"Delete"按钮——强制消歧
ForEach(items) { item in
    Button("Delete") { delete(item) }
}

// ✅ 唯一标签
ForEach(items) { item in
    Button("Delete") { delete(item) }
        .accessibilityLabel("Delete \(item.name)")
}
```

---

## 自定义操作

当 UI 仅可通过滑动到达时（例如列表中的滑动删除），Voice Control 需要语音可访问的替代方案。

### SwiftUI

```swift
// "Show actions for 3"在 Voice Control 中显示为">>"
MessageRow(message: message)
    .accessibilityAction(named: "Reply") { reply(message) }
    .accessibilityAction(named: "Archive") { archive(message) }
    .accessibilityAction(named: "Delete") { delete(message) }
```

自定义操作在"Show numbers"模式中元素编号旁显示">>"指示器。

### UIKit

```swift
cell.accessibilityCustomActions = [
    UIAccessibilityCustomAction(name: "Reply") { [weak self] _ in
        self?.reply(message)
        return true
    },
    UIAccessibilityCustomAction(name: "Archive") { [weak self] _ in
        self?.archive(message)
        return true
    }
]
```

### 揭示隐藏 UI

如果内容仅在悬停/滑动时可见（例如滑动行后显示删除按钮），Voice Control 用户无法在没有显式操作的情况下发现或激活它。

```swift
// 列表行上的隐藏操作
struct ArticleRow: View {
    var article: Article
    @State private var showDeleteConfirm = false

    var body: some View {
        Text(article.title)
            .swipeActions {
                Button(role: .destructive) { delete(article) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            // 滑动删除的 Voice Control 替代方案
            .accessibilityAction(named: "Delete article") { delete(article) }
    }
}
```

---

## 文字输入和编辑

所有文字字段都必须与 Voice Control 的文字命令配合工作。

### Voice Control 使用的命令

| 命令 | 操作 |
|---|---|
| "Type Hello" | 在光标处插入"Hello" |
| "Select Hello" | 选择文字"Hello" |
| "Select all" | 选择所有文字 |
| "Delete that" | 删除选中的文字 |
| "Capitalize that" | 大写选中的文字 |
| "Bold that" | 加粗选中的文字（富文本） |

### 要求

```swift
// ✅ 原生 TextField——自动工作
TextField("Email", text: $email)

// ✅ 原生 UITextField——自动工作
let field = UITextField()
field.placeholder = "Email"

// ⚠️ 自定义文字输入——必须彻底测试
// Voice Control 文字选择和删除在没有原生 UITextInput 实现的情况下可能不工作
```

**始终用以下命令测试每个文字字段：**
1. "Type [文字]"——插入文字
2. "Select [可见单词]"——选择特定文字
3. "Delete that"——删除选中的文字

### 限时交互

如果你的 UI 自动隐藏或超时（例如 3 秒后隐藏的媒体播放器控制栏），Voice Control 用户需要时间发出命令。

没有公开的运行时 API 可检测 Voice Control 当前是否活跃。

- 尽可能避免主要操作的自动隐藏。
- 如果控件必须消失，提供显式方式使其保持足够长的可见时间以供语音命令。
- 将此视为 Voice Control 测试中的手动验证要求。

---

## 滚动和手势

### 导航语音命令

| 命令 | 效果 |
|---|---|
| "Scroll up/down/left/right" | 滚动当前滚动视图 |
| "Scroll to top/bottom" | 滚动到边缘 |
| "Pan left/right/up/down" | 平移地图或画布 |
| "Zoom in/out" | 缩放手势 |
| "Swipe left/right" | 滑动手势 |
| "Tap and hold [元素]" | 长按 |

### 多点触控手势

某些手势有内置的 Voice Control 等价物。自定义多点触控手势**不会**自动与 Voice Control 配合工作，需要自定义操作。

```swift
// 双指捏合——不会自动可访问
// 添加语音可访问的替代方案：
PinchableView()
    .accessibilityAction(named: "Zoom in") { scale *= 1.5 }
    .accessibilityAction(named: "Zoom out") { scale /= 1.5 }
    .accessibilityAction(named: "Reset zoom") { scale = 1.0 }
```

---

## SiriKit 和 App Intents

实现 App Intents 使 Voice Control 用户能够用自然语言触发应用功能——比"Show numbers"方式更深入。

```swift
struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Message"

    @Parameter(title: "Recipient")
    var recipient: String

    func perform() async throws -> some IntentResult {
        await sendMessage(to: recipient)
        return .result()
    }
}
```

---

## 测试清单

在设备上测试（非 Simulator）。在 Settings → Accessibility → Voice Control 中启用 Voice Control。

### "Show numbers"测试
- [ ] 每个按钮、链接和交互元素都有数字
- [ ] 覆盖层中无交互元素缺失
- [ ] "Tap [数字]"正确激活每个元素

### "Show names"测试
- [ ] 每个元素在覆盖层中都有可见文字标签
- [ ] 标签与 UI 中的可见文字匹配
- [ ] 无元素显示通用标签（"button"、"image"）

### 语音激活测试
- [ ] "Tap [可见文字]"对每个有标签的按钮都有效
- [ ] "Tap [输入标签]"对有备选名称的元素有效
- [ ] 自定义操作显示为">>"且可激活

### 文字输入测试
- [ ] "Type [文字]"在每个文字字段中都有效
- [ ] "Select [单词]"正确选择文字
- [ ] "Delete that"删除选中的文字

### 手势测试
- [ ] 仅滑动 UI 有语音可访问的自定义操作
- [ ] 自定义多点触控手势有语音替代方案

---

## 常见失败

| 失败 | 原因 | 修复 |
|---|---|---|
| 元素在"Show numbers"中缺失 | 未被识别为交互元素 | 使用 `Button`，添加 `.accessibilityTraits(.button)` |
| "Tap Send"失败但按钮存在 | `accessibilityLabel` 是"Submit"而非"Send" | 使标签匹配可见文字或添加 `.accessibilityInputLabels(["Send"])` |
| 自定义文字字段中听写失败 | 无 `UITextInput` 实现 | 使用原生 `UITextField`/`UITextView` 或实现 `UITextInput` |
| 滑动删除对 Voice Control 不可见 | 滑动操作无语音替代方案 | 添加 `.accessibilityAction(named: "Delete")` |
| 自动隐藏 UI 在命令完成前消失 | 超时太短 | 无障碍功能活跃时延长超时 |
| 相同标签需要消歧 | 两个元素同名 | 添加唯一上下文："Delete Photo"、"Delete Video" |
| 自定义点击处理未被发现 | `.onTapGesture` 无无障碍角色 | 改用 `Button` |
