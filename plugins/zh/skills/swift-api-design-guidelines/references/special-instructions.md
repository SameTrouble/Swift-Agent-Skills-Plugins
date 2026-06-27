# 特殊指令

## 元组与闭包命名
- 在 API 签名中为元组成员添加标签。
- 在 API 中出现的闭包参数处为其命名。
- 这些名称提升调用处可读性和文档实用性。

```swift
mutating func ensureUniqueStorage(
    minimumCapacity requestedCapacity: Int,
    allocate: (_ byteCount: Int) -> UnsafePointer<Void>
) -> (reallocated: Bool, capacityChanged: Bool)
```

## 谨慎对待无约束多态
- `Any`、`AnyObject` 和无约束泛型会使重载集合变得含糊。
- 当弱类型使区分消失时，语义重载族仍需显式命名。

含糊模式：
```swift
values.append([2, 3, 4]) // 元素追加还是序列追加？
```

首选消歧方式：
```swift
append(_ newElement: Element)
append(contentsOf newElements: S)
```

## 实践规则
- 如果在弱类型值的调用处重载含义不明显，重命名 API 以使意图显式。
