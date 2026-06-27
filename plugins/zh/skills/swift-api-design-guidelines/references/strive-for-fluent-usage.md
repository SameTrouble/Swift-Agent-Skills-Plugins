# 力求流畅使用

## 构建符合语法的调用处
- 优先选择在使用处形成可读短语的名称。
- 流畅性对基名和前几个参数最为重要。

```swift
x.insert(y, at: z)
x.subviews(havingColor: color)
```

## 工厂与初始化器命名
- 工厂方法以 `make` 开头。
- 不要强行将第一个参数与基名组成短语。

```swift
factory.makeWidget(gears: 42, spindles: 14)
let link = Link(to: destination)
```

## 按副作用命名
- 无副作用：名词/查询风格（`distance(to:)`、`isEmpty`）。
- 有副作用：祈使动词风格（`sort()`、`append(_)`、`print(_)`）。

## Mutating/Nonmutating 配对
- 如果自然是动词：
  - Mutating：祈使式（`sort`、`append`）
  - Nonmutating：分词式（`sorted`、`appending`/`stripping...`）
- 如果自然是名词：
  - Nonmutating 名词（`union`）
  - Mutating 加 `form` 前缀（`formUnion`）

## 协议与类型命名
- 描述"某物是什么"的协议应为名词（`Collection`）。
- 能力协议应以 `able`、`ible` 或 `ing` 结尾（`Equatable`、`ProgressReporting`）。
- 类型、属性、常量和变量应读起来像名词。
