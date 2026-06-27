# 深度链接与导航

## 意图

将外部 URL 路由到应用内目标，并在需要时回退到系统处理。

## 核心模式

- 在路由器中集中 URL 处理（`handle(url:)`、`handleDeepLink(url:)`）。
- 注入一个 `OpenURLAction` 处理器委托给路由器。
- 对应用 scheme 链接用 `.onOpenURL`，如需要将其转换为 web URL。
- 让路由器决定是导航还是外部打开。

## 示例：路由器入口点

```swift
@MainActor
final class RouterPath {
  var path: [Route] = []
  var urlHandler: ((URL) -> OpenURLAction.Result)?

  func handle(url: URL) -> OpenURLAction.Result {
    if isInternal(url) {
      navigate(to: .status(id: url.lastPathComponent))
      return .handled
    }
    return urlHandler?(url) ?? .systemAction
  }

  func handleDeepLink(url: URL) -> OpenURLAction.Result {
    // 解析联邦 URL，然后导航。
    navigate(to: .status(id: url.lastPathComponent))
    return .handled
  }
}
```

## 示例：附加到根视图

```swift
extension View {
  func withLinkRouter(_ router: RouterPath) -> some View {
    self
      .environment(
        \.openURL,
        OpenURLAction { url in
          router.handle(url: url)
        }
      )
      .onOpenURL { url in
        router.handleDeepLink(url: url)
      }
  }
}
```

## 应保留的设计选择

- 将 URL 解析和决策逻辑保留在路由器内部。
- 避免在多处处理深度链接；一个入口点足够。
- 始终提供回退到 `OpenURLAction` 或 `UIApplication.shared.open`。

## 陷阱

- 不要假设 URL 是内部的；先校验。
- 解析远程链接时避免阻塞 UI；用 `Task`。
