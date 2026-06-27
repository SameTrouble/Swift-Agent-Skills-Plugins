# 基本原则

## 核心优先级
- 使用点的清晰度是最重要的设计目标。
- 清晰度比简洁性更重要。
- 在真实的调用处上下文中评估声明，而非孤立地评估。

## 文档是 API 设计的一部分
- 为每个声明编写文档注释。
- 如果 API 难以简单描述，可能需要重新设计。
- 使用 Swift Markdown 和公认的符号标记。

## 摘要编写规则
- 以能独立成立的摘要开头。
- 优先使用以句号结尾的单一句片段。
- 描述：
  - 函数/方法：做什么以及返回什么。
  - 下标：访问什么。
  - 初始化器：创建什么。
  - 其他声明：是什么。

## 建议结构
```swift
/// Returns a "view" of `self` containing the same elements in
/// reverse order.
func reversed() -> ReverseCollection
```

```swift
/// Accesses the `index`th element.
subscript(index: Int) -> Element { get set }
```

```swift
/// Creates an instance containing `n` repetitions of `x`.
init(count n: Int, repeatedElement x: Element)
```

## 额外注释内容
- 仅在能增进理解时添加额外段落。
- 在相关时使用符号标记列表项，例如：
  - `Parameter` / `Parameters`
  - `Returns`
  - `Throws`
  - `Note`
  - `Warning`
  - `SeeAlso`

## 实践检查
- 阅读一处使用点代码片段，确认无需外部解释即可明白意图。
