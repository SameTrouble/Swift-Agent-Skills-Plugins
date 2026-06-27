# Form

## 意图

用 `Form` 做结构化设置、分组输入和操作行。此模式为数据录入屏幕保持一致的布局、间距和无障碍。

## 核心模式

- 仅当 Form 在 sheet 中或没有既有导航上下文的独立视图中展示时，才将其包在 `NavigationStack` 中。
- 将相关控件分到 `Section` 块中。
- 当需要设计系统颜色时，用 `.scrollContentBackground(.hidden)` 加自定义背景色。
- 适当时应用 `.formStyle(.grouped)` 做分组样式。
- 在输入密集的表单中用 `@FocusState` 管理键盘焦点。

## 示例：设置样式表单

```swift
@MainActor
struct SettingsView: View {
  @Environment(Theme.self) private var theme

  var body: some View {
    NavigationStack {
      Form {
        Section("General") {
          NavigationLink("Display") { DisplaySettingsView() }
          NavigationLink("Haptics") { HapticsSettingsView() }
        }

        Section("Account") {
          Button("Edit profile") { /* open sheet */ }
            .buttonStyle(.plain)
        }
        .listRowBackground(theme.primaryBackgroundColor)
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
    }
  }
}
```

## 示例：带校验的模态表单

```swift
@MainActor
struct AddRemoteServerView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Theme.self) private var theme

  @State private var server: String = ""
  @State private var isValid = false
  @FocusState private var isServerFieldFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        TextField("Server URL", text: $server)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($isServerFieldFocused)
          .listRowBackground(theme.primaryBackgroundColor)

        Button("Add") {
          guard isValid else { return }
          dismiss()
        }
        .disabled(!isValid)
        .listRowBackground(theme.primaryBackgroundColor)
      }
      .formStyle(.grouped)
      .navigationTitle("Add Server")
      .navigationBarTitleDisplayMode(.inline)
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
      .scrollDismissesKeyboard(.immediately)
      .toolbar { CancelToolbarItem() }
      .onAppear { isServerFieldFocused = true }
    }
  }
}
```

## 应保留的设计选择

- 设置和输入屏幕优先用 `Form` 而非自定义栈。
- 用 `.contentShape(Rectangle())` 和行按钮上的 `.buttonStyle(.plain)` 保持行可点击。
- 用列表行背景使分区样式与主题一致。

## 陷阱

- 避免在 `Form` 内做重度自定义布局；可能导致间距问题。
- 如果需要高度自定义的布局，优先用 `ScrollView` + `VStack`。
- 不要混合多种背景策略；要么用默认 Form 样式，要么用自定义颜色。
