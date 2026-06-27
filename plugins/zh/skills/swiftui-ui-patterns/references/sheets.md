# Sheets

## 意图

用集中式 sheet 路由模式，使任何视图都能展示模态而无需属性穿透。这把 sheet 状态保留在一处，并随应用增长可扩展。

## 核心架构

- 定义一个描述每个模态且 `Identifiable` 的 `SheetDestination` 枚举。
- 将当前 sheet 存储在路由器对象中（`presentedSheet: SheetDestination?`）。
- 创建一个如 `withSheetDestinations(...)` 的视图修饰符，把枚举映射到具体 sheet 视图。
- 将路由器注入环境，使子视图能直接设置 `presentedSheet`。

## 示例：item 驱动的局部 sheet

当 sheet 状态局部于一个屏幕且不需要集中路由时使用。

```swift
@State private var selectedItem: Item?

.sheet(item: $selectedItem) { item in
  EditItemSheet(item: item)
}
```

## 示例：SheetDestination 枚举

```swift
enum SheetDestination: Identifiable, Hashable {
  case composer
  case editProfile
  case settings
  case report(itemID: String)

  var id: String {
    switch self {
    case .composer, .editProfile:
      // 使用相同 id 以确保一次只有一个编辑器类 sheet 活跃。
      return "editor"
    case .settings:
      return "settings"
    case .report:
      return "report"
    }
  }
}
```

## 示例：withSheetDestinations 修饰符

```swift
extension View {
  func withSheetDestinations(
    sheet: Binding<SheetDestination?>
  ) -> some View {
    sheet(item: sheet) { destination in
      Group {
        switch destination {
        case .composer:
          ComposerView()
        case .editProfile:
          EditProfileView()
        case .settings:
          SettingsView()
        case .report(let itemID):
          ReportView(itemID: itemID)
        }
      }
    }
  }
}
```

## 示例：从子视图展示

```swift
struct StatusRow: View {
  @Environment(RouterPath.self) private var router

  var body: some View {
    Button("Report") {
      router.presentedSheet = .report(itemID: "123")
    }
  }
}
```

## 所需连接

要使子视图工作，父视图必须：
- 持有路由器实例，
- 附加 `withSheetDestinations(sheet: $router.presentedSheet)`（或等价的 `sheet(item:)` 处理器），并
- 在 sheet 修饰符之后用 `.environment(router)` 注入，使模态内容继承它。

这使子视图对 `router.presentedSheet` 的赋值在根视图驱动展示。

## 示例：需要自身导航的 sheets

把 sheet 内容包在 `NavigationStack` 中，使其能在模态内 push。

```swift
struct NavigationSheet<Content: View>: View {
  var content: () -> Content

  var body: some View {
    NavigationStack {
      content()
        .toolbar { CloseToolbarItem() }
    }
  }
}
```

## 示例：sheet 持有其操作

当操作属于模态本身时，把关闭和确认逻辑保留在 sheet 内部。

```swift
struct EditItemSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Store.self) private var store

  let item: Item
  @State private var isSaving = false

  var body: some View {
    VStack {
      Button(isSaving ? "Saving..." : "Save") {
        Task { await save() }
      }
    }
  }

  private func save() async {
    isSaving = true
    await store.save(item)
    dismiss()
  }
}
```

## 应保留的设计选择

- 集中 sheet 路由，使功能能展示模态而无需穿过多层连接绑定。
- 用 `sheet(item:)` 保证单一 sheet 活跃，并从枚举驱动展示。
- 当相关 sheets 互斥时（如编辑器流程），把它们归到同一 `id`。
- 保持 sheet 视图轻量并由更小视图组合；避免大型单体。
- 让 sheet 持有其操作并在内部调用 `dismiss()`，而非通过多层转发 `onCancel` 或 `onConfirm` 闭包。

## 陷阱

- 避免对同一关注点混合 `sheet(isPresented:)` 和 `sheet(item:)`；优先用单一枚举。
- 当展示状态已携带选中模型时，避免在 sheet body 内用 `if let`；优先用 `sheet(item:)`。
- 不要在 `SheetDestination` 内存储重状态；传递轻量标识符或模型。
- 如果同一屏幕可出现多个 sheet，给它们不同的 `id` 值。
