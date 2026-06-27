# 参数

## 为文档质量选择名称
- 参数名不出现在大多数调用处，但它们决定文档清晰度。
- 选择在摘要和参数描述中读起来自然的名称。

```swift
/// Returns the elements of `self` that satisfy `predicate`.
func filter(_ predicate: (Element) -> Bool) -> [Element]
```

## 为常见情况优先使用默认值
- 当某个值被常用时，使用默认值。
- 默认值减少常见调用处的噪音并提升可读性。

```swift
lastName.compare(royalFamilyName)
```

## 优先使用带默认值的单一 API 而非方法族
- 多个语义大多共享的重载会增加认知负担。
- 一个带默认值的方法通常更易学习和维护。

## 将带默认值的参数放在末尾附近
- 不带默认值的参数通常承载核心语义。
- 保持调用模式稳定且可预测。

## `#fileID`、`#filePath`、`#file`
- 生产 API 优先使用 `#fileID` 以节省空间并避免暴露完整路径。
- 在完整路径有意有用时（如测试/工具）使用 `#filePath`。
- 在需要 Swift 5.2 及更早版本兼容时使用 `#file`。
