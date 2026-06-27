# 之前/之后：SwiftUI 无障碍

带优先级层级注释的具体代码转换。每个示例展示不可访问版本、修正版本以及每个更改的摘要。

优先级层级：
- **Blocks Assistive Tech** —— 元素完全不可达或不可用
- **Degrades Experience** —— 可达但摩擦显著
- **Incomplete Support** —— 阻止 Nutrition Label 声明的缺口

## 目录

### Blocks Assistive Tech
- 仅图标按钮缺少标签
- 使用 `onTapGesture` 的可点击视图
- VoiceOver 朗读装饰性图片

### Degrades Experience
- 标签包含控件类型
- 状态嵌入标签
- 触摸目标太小
- 长按菜单无 VoiceOver 等价物

### Incomplete Support
- 文字不随 Dynamic Type 缩放
- Reduce Motion 启用时播放动画
- 仅颜色状态指示器
- VoiceOver 模态允许访问背景
- 自定义滑块缺少可调支持

---

## [Blocks Assistive Tech] 仅图标按钮缺少标签

**问题：** VoiceOver 朗读"square.and.arrow.up"（SF Symbol 名称）。Voice Control 无法识别按钮。两个功能都无法正确使用此控件。

```swift
// ❌ 之前
Button(action: shareDocument) {
    Image(systemName: "square.and.arrow.up")
}
```

```swift
// ✅ 之后
Button(action: shareDocument) {
    Image(systemName: "square.and.arrow.up")
}
.accessibilityLabel("Share")                           // [VERIFY] confirm this matches intent
.accessibilityInputLabels(["Share", "Share Document"]) // Voice Control alternate names
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `.accessibilityLabel("Share")` | VoiceOver 朗读操作而非符号名 |
| 添加 `.accessibilityInputLabels(["Share", "Share Document"])` | Voice Control："Tap Share"和"Tap Share Document"都可用 |
| 添加 `[VERIFY]` 注释 | 标签从符号推断——开发者必须确认匹配操作 |

---

## [Blocks Assistive Tech] 使用 `onTapGesture` 的可点击视图

**问题：** VoiceOver 无标签并将其视为非交互。Voice Control 的"Show numbers"不包含它。Switch Control 跳过它。

```swift
// ❌ 之前
HStack {
    Image(product.thumbnail)
    VStack(alignment: .leading) {
        Text(product.name)
        Text(product.price, format: .currency(code: "USD"))
    }
}
.onTapGesture { openProduct(product) }
```

```swift
// ✅ 之后
Button(action: { openProduct(product) }) {
    HStack {
        Image(product.thumbnail)
            .accessibilityHidden(true)  // 装饰性——名称通过下方标签朗读
        VStack(alignment: .leading) {
            Text(product.name)
            Text(product.price, format: .currency(code: "USD"))
        }
    }
}
.accessibilityLabel("\(product.name), \(product.formattedPrice)")
.accessibilityHint("Opens product details")
```

**更改：**
| 更改 | 原因 |
|---|---|
| 用 `Button` 替换 `onTapGesture` | `Button` 对 VoiceOver、Voice Control 和键盘自动可交互 |
| 添加 `.accessibilityLabel(...)` | 合并标签防止 VoiceOver 分别朗读子元素 |
| 图片上添加 `.accessibilityHidden(true)` | 缩略图与标签冗余——从无障碍树隐藏 |
| 添加 `.accessibilityHint(...)` | 解释结果而不与标签冗余 |

---

## [Blocks Assistive Tech] VoiceOver 朗读装饰性图片

**问题：** VoiceOver 朗读"Image: background-wave"打断阅读流程。

```swift
// ❌ 之前
Image("background-wave")
    .frame(height: 200)
```

```swift
// ✅ 之后
Image("background-wave")
    .frame(height: 200)
    .accessibilityHidden(true)
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `.accessibilityHidden(true)` | 从无障碍树完全移除装饰性图片 |

---

## [Degrades Experience] 标签包含控件类型

**问题：** VoiceOver 朗读"Delete button, button"——双重朗读类型。

```swift
// ❌ 之前
Button("Delete button") { delete(item) }
```

```swift
// ✅ 之后
Button("Delete") { delete(item) }
    .accessibilityLabel("Delete \(item.name)") // 每项唯一标签
```

**更改：**
| 更改 | 原因 |
|---|---|
| 从标签中移除"button" | VoiceOver 从 `.isButton` 特质自动添加"button" |
| 标签中添加项目名 | 防止多个 Delete 按钮出现时需要消歧 |

---

## [Degrades Experience] 状态嵌入标签

**问题：** 收藏状态变化时，VoiceOver 重新朗读整个标签。状态应是特质，而非标签变化。

```swift
// ❌ 之前
Button(action: toggleFavorite) {
    Image(systemName: item.isFavorited ? "star.fill" : "star")
}
.accessibilityLabel(item.isFavorited ? "Favorited" : "Not favorited")
```

```swift
// ✅ 之后
Button(action: toggleFavorite) {
    Image(systemName: item.isFavorited ? "star.fill" : "star")
}
.accessibilityLabel("Favorite")
.accessibilityAddTraits(item.isFavorited ? .isSelected : [])
.accessibilityHint(item.isFavorited ? "Removes from favorites" : "Adds to favorites")
```

**更改：**
| 更改 | 原因 |
|---|---|
| 标签始终为"Favorite" | 稳定标签——状态变化时 VoiceOver 不重新朗读 |
| 收藏时添加 `.accessibilityAddTraits(.isSelected)` | VoiceOver 朗读"selected"——对 iOS 13–16 target 正确 |
| 添加描述结果的 `.accessibilityHint(...)` | 告诉用户基于当前状态激活会做什么 |

> **iOS 17+ 注意：** 对于开关控件，优先使用 `.accessibilityAddTraits(.isToggle)` 而非 `.isSelected`。`.isToggle` 标识控件*类型*（二进制开/关），而 `.isSelected` 传达*当前选择状态*（例如选中的标签页）。对于面向 iOS 17+ 的收藏/书签按钮，使用 `.isToggle` 并通过 `accessibilityValue("On")` / `accessibilityValue("Off")` 表达当前状态。

---

## [Degrades Experience] 触摸目标太小

**问题：** 心形图标为 20×20pt。点击区域对许多用户来说太小，尤其是运动障碍用户。

```swift
// ❌ 之前
Image(systemName: "heart")
    .font(.system(size: 20))
    .onTapGesture { toggleFavorite() }
```

```swift
// ✅ 之后
Button(action: toggleFavorite) {
    Image(systemName: "heart")
        .font(.system(size: 20))
}
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
.accessibilityLabel("Favorite")
```

**更改：**
| 更改 | 原因 |
|---|---|
| 将 `onTapGesture` 改为 `Button` | 使元素对 VoiceOver 和 Voice Control 可访问 |
| 添加 `.frame(minWidth: 44, minHeight: 44)` | 确保最小 44×44pt 触摸目标 |
| 添加 `.contentShape(Rectangle())` | 确保整个 frame 可点击，不仅是图标 |
| 添加 `.accessibilityLabel("Favorite")` | 仅图标按钮需要显式标签 |

---

## [Degrades Experience] 长按菜单无 VoiceOver 等价物

**问题：** 上下文菜单仅通过长按可访问。VoiceOver 用户无法发现或触发这些操作。

```swift
// ❌ 之前
MessageRow(message: message)
    .contextMenu {
        Button("Reply") { reply(message) }
        Button("Forward") { forward(message) }
        Button("Delete", role: .destructive) { delete(message) }
    }
```

```swift
// ✅ 之后
MessageRow(message: message)
    .contextMenu {
        Button("Reply") { reply(message) }
        Button("Forward") { forward(message) }
        Button("Delete", role: .destructive) { delete(message) }
    }
    // VoiceOver: Actions 转子；Voice Control: ">>" 指示器
    .accessibilityAction(named: "Reply") { reply(message) }
    .accessibilityAction(named: "Forward") { forward(message) }
    .accessibilityAction(named: "Delete") { delete(message) }
```

**更改：**
| 更改 | 原因 |
|---|---|
| 为每个操作添加 `.accessibilityAction(named:)` | VoiceOver Actions 转子可访问它们；Voice Control 显示">>" |
| 保留上下文菜单 | 视力用户保留预期手势——不移除 |

---

## [Incomplete Support] 文字不随 Dynamic Type 缩放

**问题：** 固定字体大小意味着即使用户选择了更大的无障碍大小，文字仍然很小。

```swift
// ❌ 之前
Text(article.title)
    .font(.system(size: 17))
Text(article.body)
    .font(.system(size: 14))
```

```swift
// ✅ 之后
Text(article.title)
    .font(.headline)           // 随 Dynamic Type 缩放
Text(article.body)
    .font(.body)               // 随 Dynamic Type 缩放
```

**更改：**
| 更改 | 原因 |
|---|---|
| `.system(size: 17)` → `.headline` | 语义文字样式随用户首选大小缩放 |
| `.system(size: 14)` → `.body` | 语义文字样式缩放；作为正文内容朗读 |

---

## [Incomplete Support] Reduce Motion 启用时播放动画

**问题：** 即使用户启用了 Reduce Motion 以避免前庭问题，滑动转场仍然播放。

```swift
// ❌ 之前
if isVisible {
    DetailView()
        .transition(.slide)
}
```

```swift
// ✅ 之后
@Environment(\.accessibilityReduceMotion) var reduceMotion

// 在 body 中：
if isVisible {
    DetailView()
        .transition(reduceMotion ? .opacity : .slide)
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 读取 `@Environment(\.accessibilityReduceMotion)` | 检测用户偏好 |
| reduce motion 开启时将 `.slide` 切换为 `.opacity` | 淡入淡出保留含义而不触发前庭运动 |

---

## [Incomplete Support] 仅颜色状态指示器

**问题：** 在线状态仅通过颜色显示（绿色 = 在线，红色 = 离线）。灰度测试和 Differentiate Without Color 失败。

```swift
// ❌ 之前
Circle()
    .fill(user.isOnline ? .green : .red)
    .frame(width: 12, height: 12)
```

```swift
// ✅ 之后
Group {
    if user.isOnline {
        Circle()
            .fill(.green)
            .frame(width: 12, height: 12)
    } else {
        Circle()
            .fill(.red)
            .overlay(
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            )
            .frame(width: 12, height: 12)
    }
}
.accessibilityLabel(user.isOnline ? "Online" : "Offline")
```

**更改：**
| 更改 | 原因 |
|---|---|
| 离线圆圈上添加 xmark 图标 | 形状在灰度下区分状态 |
| 添加 `.accessibilityLabel(...)` | VoiceOver 朗读语义状态，不仅是颜色 |
| 保留颜色区分 | 不破坏视力用户——形状是附加的 |

---

## [Incomplete Support] VoiceOver 模态允许访问背景

**问题：** 模态出现时，VoiceOver 仍可滑动到达后面的元素。

```swift
// ❌ 之前
struct ConfirmationModal: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Text("Are you sure?")
            Button("Confirm") {
                // ...
                isPresented = false
            }
            Button("Cancel") { isPresented = false }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
```

```swift
// ✅ 之后
struct ConfirmationModal: View {
    @Binding var isPresented: Bool
    @AccessibilityFocusState private var isConfirmFocused: Bool

    var body: some View {
        VStack {
            Text("Are you sure?")
            Button("Confirm") {
                // ...
                isPresented = false
            }
                .accessibilityFocused($isConfirmFocused)
            Button("Cancel") { isPresented = false }
        }
        .padding()
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
        .onAppear { isConfirmFocused = true }
    }
}

// 出现位置——优先使用 .sheet() 自动捕获焦点：
.sheet(isPresented: $showConfirm) {
    ConfirmationModal(isPresented: $showConfirm)
}
```

**更改：**
| 更改 | 原因 |
|---|---|
| 使用 `.sheet()` 出现 | `.sheet()` 自动捕获 VoiceOver 焦点 |
| 添加 `@AccessibilityFocusState` + `.onAppear` | 模态出现时焦点移到 Confirm 按钮 |
| 添加 `.accessibilityElement(children: .contain)` | 确保模态内逻辑分组 |

---

## [Incomplete Support] 自定义滑块缺少可调支持

**问题：** VoiceOver 到达滑块但无法改变其值（无上下滑动支持）。

```swift
// ❌ 之前
CustomSliderView(value: $brightness)
    .accessibilityLabel("Brightness")
```

```swift
// ✅ 之后
CustomSliderView(value: $brightness)
    .accessibilityLabel("Brightness")
    .accessibilityValue("\(Int(brightness * 100)) percent")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: brightness = min(1, brightness + 0.05)
        case .decrement: brightness = max(0, brightness - 0.05)
        @unknown default: break
        }
    }
```

**更改：**
| 更改 | 原因 |
|---|---|
| 添加 `.accessibilityValue(...)` | 聚焦时朗读当前值 |
| 添加 `.accessibilityAdjustableAction(...)` | 启用 VoiceOver 上下滑动改变值 |
