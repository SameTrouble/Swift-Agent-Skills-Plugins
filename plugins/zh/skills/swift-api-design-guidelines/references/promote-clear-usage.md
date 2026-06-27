# 促进清晰使用

## 包含清晰所需的词
- 保留在调用处避免歧义所需的所有词。
- 不要移除承载语义区分的词。

```swift
employees.remove(at: index)   // 清晰的基于位置的移除
employees.remove(index)       // 含糊
```

## 省略不必要的词
- 移除重复类型信息且无含义的词。
- 优先使用关注角色的词而非关注类型的词。

```swift
allViews.remove(cancelButton)         // 首选
allViews.removeElement(cancelButton)  // 冗余
```

## 按角色而非类型命名
- 变量、参数和关联类型应描述角色。
- 当角色名更好时，避免将类型名复用为标识符。

```swift
var greeting = "Hello"
func restock(from supplier: WidgetFactory)
associatedtype ContentView: View
```

## 弥补弱类型信息
- 弱类型值（`Any`、`NSObject`、原语）通常需要额外的角色词。
- 添加角色名词以消除意图歧义。

```swift
func addObserver(_ observer: NSObject, forKeyPath path: String)
```

## 审查启发式
- 问："读者能否仅从调用处文本推断出语义？"
- 如果不能，添加所需的最小命名上下文。
