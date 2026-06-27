# 使用谓词

SwiftData 谓词仅支持 Swift 功能的一个子集。有些操作被标记为不受支持，意味着它们无法编译。另一些操作*未*被标记为不受支持，但实际上仍不受支持，意味着它们能编译但在运行时崩溃。

本指南包含关于何时使用什么的具体指导。


## 字符串匹配

编写查询谓词执行字符串匹配时，始终使用 `localizedStandardContains()`，而非尝试使用 `lowercased().contains()` 或类似方法。

例如，这样是正确的：

```swift
@Query(filter: #Predicate<Movie> {
    $0.name.localizedStandardContains("titanic")
}) private var movies: [Movie]
```


## hasPrefix()

`hasPrefix()` 和 `hasSuffix()` 在 SwiftData 谓词中不受支持。如果想使用 `hasPrefix()`，应改用 `starts(with:)`，如下所示：

```swift
@Query(filter: #Predicate<Website> {
    $0.type.starts(with: "https://apple.com")
}) private var appleLinks: [Website]
```


## 不受支持的谓词

许多常用方法在 SwiftData 中没有等价物，将无法编译。例如，所有这些常用操作都不受支持：

- `String.hasSuffix()`
- `String.lowercased()`
- `Sequence.map()`
- `Sequence.reduce()`
- `Sequence.count(where:)`
- `Collection.first`

也不允许使用自定义运算符。


## 危险的谓词

有些 SwiftData 谓词能干净地编译，但在运行时会失败甚至崩溃。

例如，这是一个有效的谓词，设计用于仅显示演员表非空的电影：

```swift
@Query(filter: #Predicate<Movie> { !$0.cast.isEmpty }, sort: \Movie.name) private var movies: [Movie]
```

然而，*这个*查询看起来做同样的事，但会在运行时崩溃：

```swift
@Query(filter: #Predicate<Movie> { $0.cast.isEmpty == false }, sort: \Movie.name) private var movies: [Movie]
```

永远不要尝试创建使用计算属性、`@Transient` 属性或自定义 `Codable` 结构体数据的查询谓词。它们可能干净地编译，但在运行时会崩溃。

所有谓词必须依赖于实际存储在数据库中作为 `@Model` 类的数据。

永远不要尝试在谓词中使用正则表达式。它们会干净地编译但在运行时失败。因此，这是*不允许*的：

```swift
@Query(filter: #Predicate<Movie> {
    $0.name.contains(/Titanic/)
}, sort: \Movie.name)
private var movies: [Movie]
```
