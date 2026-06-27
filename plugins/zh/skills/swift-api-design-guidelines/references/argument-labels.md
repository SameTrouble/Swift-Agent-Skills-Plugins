# 参数标签

## 仅在仍然清晰时省略标签
- 仅当无标签参数无法被有效区分时，才省略所有标签。

示例：
- `min(x, y)`
- `zip(a, b)`

## 保值转换初始化器
- 为保值转换省略第一个参数标签。
- 第一个参数应为转换源。

```swift
let value = Int64(someUInt32)
```

## 介词短语规则
- 如果第一个参数是介词短语的一部分，通常包含以介词开头的标签。

```swift
x.removeBoxes(havingLength: 12)
```

例外：
- 当前几个参数是一个抽象的组成部分时，将标签边界移到介词之后。

```swift
a.moveTo(x: b, y: c)
a.fadeFrom(red: b, green: c, blue: d)
```

## 语法短语规则
- 如果第一个参数构成语法短语的一部分，省略其标签并将前导词移入基名。

```swift
x.addSubview(y)
```

## 为其余一切加标签
- 如果第一个参数不是语法短语的一部分，为其加标签。
- 除非有特定规则证明省略合理，否则为所有剩余参数加标签。

```swift
view.dismiss(animated: false)
words.split(maxSplits: 12)
students.sorted(isOrderedBefore: Student.namePrecedes)
```
