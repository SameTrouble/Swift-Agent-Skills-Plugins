# 类继承

在支持 iOS 26 及其他协同发布版本（macOS 26 等）时，SwiftData 支持模型的类继承。

**重要：** 这不是一个常用功能；仅在实际有收益时才添加模型子类化。协议等替代方案通常更简单、更好。

这与 Swift 中常规的类继承工作方式相同，但是，子类必须显式标记 `@available` 为 26 版本或更高，例如 iOS 26。即使 iOS 26 被设置为最低部署目标，这也同样需要。

例如：

```swift
@Model class Article {
    var type: String

    init(type: String) {
        self.type = type
    }
}

@available(iOS 26, *)
@Model class Tutorial: Article {
    var difficulty: Int

    init(difficulty: Int) {
        self.difficulty = difficulty
        super.init(type: "Tutorial")
    }
}

@available(iOS 26, *)
@Model class News: Article {
    var topic: String

    init(topic: String) {
        self.topic = topic
        super.init(type: "News")
    }
}
```

注意父类和子类都必须使用 `@Model` 宏。

**重要：** 当使用 26 版本或更高作为最低部署目标时，我们仍然必须用 `@available` 标记子类化的模型。但是，我们*不需要*对使用该模型的代码做同样的标记，因为 Xcode 可以匹配部署目标与模型可用性。

在创建模型容器时将模式作为一部分提供时，确保同时列出父类及其子类——SwiftData *无法*自行推断这种关联。

如果你创建了一个到带有子类的模型的关系，该关系可能包含父类或其任何子类。

例如，这里的 `articles` 数组可能包含 `Article`、`Tutorial` 或 `News` 实例：

```swift
@Model class Magazine {
    @Relationship(deleteRule: .cascade) var articles: [Article]

    init(articles: [Article]) {
        self.articles = articles
    }
}
```

如果只支持一个子类，应具体写明。如果几个但不是全部子类应在关系中，你可能只能添加另一层子类：BaseClass -> Subclass -> Subsubclass。然而，这不是个好主意——深层子类化通常不被推荐，且会增加迁移的复杂性。


## 使用子类进行过滤

模型子类化的一个重要好处是，我们可以使用 `@Query` 查找特定子类，*或者*查找基类，这将自动返回所有子类。

例如，我们可以像这样仅加载教程：

```swift
@Query private var tutorials: [Tutorial]
```

或者像这样加载*所有*文章，包括教程：

```swift
@Query private var articles: [Article]
```

如果想加载特定子类而不加载父类，使用 `is` 配合 `#Predicate` 宏进行过滤：

```swift
@Query(filter: #Predicate<Article> {
    $0 is Tutorial || $0 is News
}) private var tutorialsAndNews: [Article]
```

**重要：** 结果数组元素的类型是 `Article`（父类），因此必须使用类型转换来访问子类属性和方法。

可以在谓词内部进行类型转换，以基于子类属性进行过滤。例如，这会查找较简单的教程和一般新闻，以创建适合首页的文章列表：

```swift
@Query(filter: #Predicate<Article> { article in
    if let tutorial = article as? Tutorial {
        tutorial.difficulty < 3
    } else if let news = article as? News {
        news.topic == "General"
    } else {
        false
    }
}) private var frontPageArticles: [Article]
```

处理结果数据时，使用 `as` 进行常规 Swift 类型转换可以正常工作。
