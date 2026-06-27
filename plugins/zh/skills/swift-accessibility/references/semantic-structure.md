# 语义结构

覆盖分组、阅读顺序、焦点管理、自定义转子、模态焦点捕获和标题层级——决定辅助技术如何导航和理解你的 UI 的无障碍结构层。

## 目录
- [分组元素](#分组元素)
- [阅读顺序和排序优先级](#阅读顺序和排序优先级)
- [焦点管理](#焦点管理)
- [自定义转子](#自定义转子)
- [模态焦点捕获](#模态焦点捕获)
- [标题层级](#标题层级)
- [UIAccessibilityContainer (UIKit)](#uiaccessibilitycontainer-uikit)
- [常见错误](#常见错误)

---

## 分组元素

### SwiftUI: `.accessibilityElement(children:)`

控制 VoiceOver 如何暴露容器的子元素。

**`.combine`** —— 将所有后代合并为一个元素。VoiceOver 按顺序朗读它们的标签。最适合形成单个语义单元的相关内容。

```swift
// ✅ 朗读为"4.5 stars, 2,304 ratings"
HStack {
    Image(systemName: "star.fill").accessibilityHidden(true)
    Text("4.5")
    Text("(2,304 ratings)")
}
.accessibilityElement(children: .combine)
// 当自动合并的文字不自然时提供显式标签：
// .accessibilityLabel("4.5 stars, 2,304 ratings")

// ✅ 产品卡片作为单个元素朗读
VStack(alignment: .leading) {
    Text(product.name)
    Text(product.price, format: .currency(code: "USD"))
    Text(product.stock > 0 ? "In stock" : "Out of stock")
}
.accessibilityElement(children: .combine)
```

**`.contain`** —— 分组元素，单独暴露每个子元素。用于需要组标签同时保留子元素可导航性的容器（例如分组的表单分区）。

```swift
// ✅ 分组侧边栏——用户可用 Switch Control 跳过整个组
SidebarView()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Sidebar navigation")
```

**`.ignore`** —— 向 VoiceOver 隐藏所有子元素。容器本身成为元素（或无标签时被隐藏）。用于纯装饰性组合。

```swift
// ✅ 带文字的装饰性分隔符
HStack {
    Divider()
    Text("OR")
    Divider()
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Or")  // 暴露语义含义

// ✅ 纯装饰性——不暴露任何内容
BackgroundAnimationView()
    .accessibilityHidden(true)  // 比全隐藏用 .ignore 更简单
```

### 显式自定义子元素

```swift
// 提供完全自定义的子元素列表
.accessibilityChildren {
    ForEach(filteredItems) { item in
        Text(item.title)
    }
}
```

### UIKit: `shouldGroupAccessibilityChildren`

将所有子元素分组为单个 Switch Control 扫描单元。不会为 VoiceOver 导航融合元素（VoiceOver 仍单独朗读每个子元素）。

```swift
// ✅ Switch Control：一次点击跳过整个侧边栏
sidebarView.shouldGroupAccessibilityChildren = true
sidebarView.accessibilityLabel = "Sidebar navigation"

// ✅ 容器向 VoiceOver 暴露有序子元素
class CardView: UIView {
    override var isAccessibilityElement: Bool {
        get { false }  // 容器不是元素
        set { }
    }
    override var accessibilityElements: [Any]? {
        get { [titleLabel, priceLabel, addButton] }
        set { }
    }
}
```

---

## 阅读顺序和排序优先级

VoiceOver 按元素在无障碍树中出现的顺序朗读，通常遵循视图层级和布局方向。当视觉顺序和语义顺序不同时重写。

### SwiftUI: `.accessibilitySortPriority(_:)`

值越高越先朗读。默认为 0。负值将元素推到最后。

```swift
// ✅ 确保关键信息在装饰性内容之前朗读
VStack {
    Text("Error: Payment failed")
        .accessibilitySortPriority(2)       // 先读
    Image(systemName: "exclamationmark.circle")
        .accessibilityHidden(true)          // 装饰性
    Text("Please update your payment method")
        .accessibilitySortPriority(1)       // 第二读
    DismissButton()
        .accessibilitySortPriority(-1)      // 最后读
}
```

### SwiftUI: `.accessibilityChildrenInNavigationOrder(_:)`

提供显式的有序标识符列表用于导航。当排序优先级不够时使用。

```swift
@Namespace var navOrder

var body: some View {
    ZStack {
        ContentView()
            .accessibilityElement(id: "content", namespace: navOrder)
        HeaderView()
            .accessibilityElement(id: "header", namespace: navOrder)
        FooterView()
            .accessibilityElement(id: "footer", namespace: navOrder)
    }
    .accessibilityChildrenInNavigationOrder(["header", "content", "footer"], namespace: navOrder)
}
```

### UIKit: `accessibilityElements` 数组

`accessibilityElements` 中元素的顺序决定 VoiceOver 导航顺序。

```swift
class DashboardView: UIView {
    override var accessibilityElements: [Any]? {
        get {
            // 显式控制阅读顺序
            [headerView, alertBanner, contentArea, actionButton]
        }
        set { }
    }
}
```

---

## 焦点管理

### SwiftUI: `@AccessibilityFocusState`

编程式地将 VoiceOver 焦点移到特定元素。当内容动态出现时（模态、错误消息、状态变化）必不可少。

```swift
@AccessibilityFocusState private var isErrorFocused: Bool

var body: some View {
    VStack {
        TextField("Email", text: $email)

        if let error = validationError {
            Text(error)
                .foregroundStyle(.red)
                .accessibilityFocused($isErrorFocused)
        }

        Button("Submit") {
            if let error = validate() {
                validationError = error
                isErrorFocused = true  // VoiceOver 跳到错误
            }
        }
    }
}
```

### 多个焦点目标

```swift
enum FormField { case name, email, password }

@AccessibilityFocusState private var focusedField: FormField?

var body: some View {
    VStack {
        TextField("Name", text: $name)
            .accessibilityFocused($focusedField, equals: .name)
        TextField("Email", text: $email)
            .accessibilityFocused($focusedField, equals: .email)
        SecureField("Password", text: $password)
            .accessibilityFocused($focusedField, equals: .password)

        Button("Next") {
            // 编程式移动焦点
            switch focusedField {
            case .name: focusedField = .email
            case .email: focusedField = .password
            default: submit()
            }
        }
    }
}
```

### `.accessibilityDefaultFocus(_:_:)` —— 初始焦点（iOS 17+）

设置视图首次出现时接收焦点的元素。

```swift
@AccessibilityFocusState private var isDefaultFocused: Bool

AlertView()
    .onAppear { isDefaultFocused = true }

// 在 AlertView 内：
Button("Confirm") { confirm() }
    .accessibilityDefaultFocus($isDefaultFocused, true)
```

### UIKit: 用通知移动焦点

```swift
// 焦点移到特定元素（部分更新）
UIAccessibility.post(notification: .layoutChanged, argument: errorLabel)

// 焦点重置到新屏幕开头（完整替换）
UIAccessibility.post(notification: .screenChanged, argument: firstInteractiveElement)

// 播报变化而不移动焦点
UIAccessibility.post(notification: .announcement, argument: "Message sent")
```

**何时使用各通知：**

| 通知 | 使用时机 |
|---|---|
| `.layoutChanged` | 屏幕部分变化（插入行、错误出现、分区展开） |
| `.screenChanged` | 整个内容变化（模态出现、标签页切换、导航 push） |
| `.announcement` | 后台状态变化——未发生布局变化 |
| `.pageScrolled` | 自定义滚动视图换页 |

---

## 自定义转子

VoiceOver 转子（双指旋转手势）让用户在特定类型的元素之间跳转。自定义转子添加应用特定的导航快捷方式。

### SwiftUI: `accessibilityRotor(_:entries:)`

```swift
// ✅ 在未读消息之间跳转
.accessibilityRotor("Unread Messages") {
    ForEach(messages.filter(\.isUnread)) { message in
        AccessibilityRotorEntry(message.preview, id: message.id)
    }
}

// ✅ 在文档中的搜索结果之间跳转
Text(documentText)
    .accessibilityRotor("Search Results") {
        ForEach(searchHighlights) { match in
            AccessibilityRotorEntry(match.text, textRange: match.range)
        }
    }
```

### 带显式焦点目标的转子

```swift
@Namespace var headingNamespace

var body: some View {
    ScrollView {
        ForEach(article.sections) { section in
            VStack(alignment: .leading) {
                Text(section.heading)
                    .font(.title2)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityRotorEntry(id: section.id, in: headingNamespace)

                Text(section.body)
            }
        }
    }
    .accessibilityRotor("Headings", entries: article.sections, id: \.id, in: headingNamespace, label: \.heading)
}
```

### UIKit: `UIAccessibilityCustomRotor`

```swift
class ArticleViewController: UIViewController {
    var headings: [Heading] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        accessibilityCustomRotors = [makeHeadingRotor()]
    }

    private func makeHeadingRotor() -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: "Headings") { [weak self] predicate in
            guard let self = self else { return nil }

            // 查找当前标题索引
            let currentIndex = self.headings.firstIndex {
                $0.view === predicate.currentItem.targetElement as? UIView
            }

            let nextIndex: Int
            switch predicate.searchDirection {
            case .next:
                nextIndex = (currentIndex.map { $0 + 1 }) ?? 0
            case .previous:
                nextIndex = currentIndex.map { $0 - 1 } ?? (self.headings.count - 1)
            @unknown default:
                return nil
            }

            guard nextIndex >= 0, nextIndex < self.headings.count else { return nil }
            let heading = self.headings[nextIndex]
            return UIAccessibilityCustomRotorItemResult(targetElement: heading.view, targetRange: nil)
        }
    }
}
```

---

## 模态焦点捕获

当模态、alert 或 sheet 出现时，VoiceOver 必须停留在模态内。用户不应能滑动到背景内容。

### SwiftUI

SwiftUI `.sheet()`、`.alert()`、`.confirmationDialog()` 和 `NavigationStack` 模态自动处理焦点捕获。

```swift
// ✅ 焦点自动捕获
.sheet(isPresented: $showSettings) {
    SettingsView()  // VoiceOver 停留在此视图内
}

// ✅ 手动出现后发送通知
.onChange(of: showCustomModal) { _, isShowing in
    if isShowing {
        // 给 SwiftUI 一点渲染时间，然后移动焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}
```

### UIKit: `accessibilityViewIsModal`

```swift
class CustomModalView: UIView {
    // 在最外层模态视图上设置，而非子视图
    override var accessibilityViewIsModal: Bool {
        get { true }
        set { }
    }
}

func presentModal() {
    let modal = CustomModalView()
    view.addSubview(modal)

    // VoiceOver 焦点移入模态
    UIAccessibility.post(notification: .screenChanged, argument: modal)
    // VoiceOver 现在忽略模态后面的所有视图
}

// ✅ 支持 Escape：双指 Z 手势（VoiceOver）/ Escape 键（Full Keyboard Access）
override func accessibilityPerformEscape() -> Bool {
    dismissModal()
    return true
}
```

**关键陷阱：**
- 在子视图（非容器）上设置 `accessibilityViewIsModal`——焦点逃逸到同级
- 忘记 `accessibilityPerformEscape`——用户无法用 VoiceOver 手势关闭
- 出现后未发送 `.screenChanged`——VoiceOver 停留在背景上

### 关闭时返回焦点

```swift
// UIKit —— 关闭后返回焦点到触发器
@AccessibilityFocusState private var returnFocus: Bool  // SwiftUI 等价

// UIKit：跟踪打开模态的元素
weak var presentingElement: UIView?

func dismissModal() {
    dismiss(animated: true) {
        // 返回焦点到触发模态的元素
        UIAccessibility.post(notification: .screenChanged, argument: self.presentingElement)
    }
}
```

---

## 标题层级

标题让 VoiceOver 用户用 Headings 转子导航——直接在分区之间跳转。

### SwiftUI

```swift
// ✅ 标记分区标题
Text("Account Settings")
    .font(.title2)
    .accessibilityAddTraits(.isHeader)

// ✅ 带级别的标题（iOS 17+）
Text("Chapter 1: Introduction")
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h1)

Text("1.1 Getting Started")
    .accessibilityAddTraits(.isHeader)
    .accessibilityHeading(.h2)

// 可用级别：.h1, .h2, .h3, .h4, .h5, .h6, .unspecified
```

### UIKit

```swift
// ✅ Header 特质
sectionLabel.accessibilityTraits = [.header, .staticText]

// 标题级别通过 accessibilityHeading（tvOS/Mac）或 iOS 上的特质设置
// iOS 不通过 UIKit API 暴露显式标题级别——
// 所有标题级别使用 accessibilityTraits = .header
```

### 文档结构模式

对于类文档内容（文章、设置页面、帮助内容）：

```swift
struct ArticleView: View {
    var article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 页面标题 —— h1
                Text(article.title)
                    .font(.largeTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h1)

                ForEach(article.sections) { section in
                    // 分区标题 —— h2
                    Text(section.title)
                        .font(.title2)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h2)

                    Text(section.body)

                    ForEach(section.subsections) { sub in
                        // 子分区标题 —— h3
                        Text(sub.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityHeading(.h3)

                        Text(sub.body)
                    }
                }
            }
            .padding()
        }
    }
}
```

---

## UIAccessibilityContainer (UIKit)

用于 VoiceOver 需要在单个 UIView 内结构化导航的复杂视图。

### `accessibilityContainerType`

为容器提供语义含义。VoiceOver 根据类型播报进入/离开。

```swift
// 表格容器——VoiceOver 进入时说"table"
tableContainerView.accessibilityContainerType = .dataTable

// 列表容器——VoiceOver 说"list"
listView.accessibilityContainerType = .list

// 地标——类似 HTML 地标
navContainerView.accessibilityContainerType = .landmark

// 语义组——无特定类型的相关内容
cardView.accessibilityContainerType = .semanticGroup
```

### `accessibilityNavigationStyle`

控制 VoiceOver 在容器内如何导航。

```swift
// .combined —— 子元素作为一组导航（一个元素）
container.accessibilityNavigationStyle = .combined

// .separate —— 子元素单独导航（大多数容器的默认）
container.accessibilityNavigationStyle = .separate

// .automatic —— 系统选择（默认）
container.accessibilityNavigationStyle = .automatic
```

### 自定义元素排序

```swift
class DashboardView: UIView {
    @IBOutlet var alertBanner: UIView!
    @IBOutlet var header: UIView!
    @IBOutlet var mainContent: UIView!
    @IBOutlet var actionButtons: UIView!

    override var isAccessibilityElement: Bool {
        get { false }   // 容器本身不是元素
        set { }
    }

    override var accessibilityElements: [Any]? {
        get {
            // Alert banner 先——关键内容
            var elements: [Any] = []
            if alertBanner.isHidden == false {
                elements.append(alertBanner!)
            }
            elements.append(contentsOf: [header!, mainContent!, actionButtons!])
            return elements
        }
        set { }
    }
}
```

---

## 常见错误

| 错误 | 修复 |
|---|---|
| 容器 `isAccessibilityElement = true` 且设置 `accessibilityElements` | 在暴露子元素的容器上设置 `isAccessibilityElement = false` |
| `.accessibilityElement(children: .combine)` 嵌套在另一个 `.combine` 内 | 扁平化结构——只有一层 combine |
| VoiceOver 朗读模态后面的背景内容 | 在最外层模态视图上设置 `accessibilityViewIsModal = true` |
| 模态出现后无焦点移动 | 发送指向模态第一个元素的 `.screenChanged` 通知 |
| 阅读顺序遵循视觉布局而非语义顺序 | 使用 `.accessibilitySortPriority` 或 `accessibilityElements` 控制顺序 |
| 数据丰富的列表无自定义转子 | 添加 `accessibilityRotor` 以高效导航长列表 |
| 分区标题缺少 `.isHeader` 特质 | 每个分区标题都应有 `.accessibilityAddTraits(.isHeader)` |
| 自定义模态无 `accessibilityPerformEscape()` | 实现以支持双指 Z 手势和 Escape 键 |
| `accessibilityViewIsModal` 在子视图而非根上 | 必须在最外层模态容器视图上 |
| 内容更新后焦点丢失（异步数据加载） | 用第一个新元素作为参数发送 `.layoutChanged` |
| 数据变化后 `accessibilityElements` 未失效 | 底层数据变化时清空缓存 + 发送 `.layoutChanged` |
