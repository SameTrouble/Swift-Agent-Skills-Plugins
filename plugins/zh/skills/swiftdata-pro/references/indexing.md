# 索引

在支持 iOS 18 及其他协同发布版本时，SwiftData 支持索引来帮助加速查询。这会对写入有少量性能损耗，因此如果数据很少被读取但频繁更新（例如日志记录），索引可能不是好选择。

索引可以针对单个属性，如下所示：

```swift
@Model class Article {
    #Index<Article>([\.type], [\.author])

    var type: String
    var author: String
    var publishDate: Date

    init(type: String, author: String, publishDate: Date) {
        self.type = type
        self.author = author
        self.publishDate = publishDate
    }
}
```

或者，当你知道某些属性经常一起使用时，可以混合使用单个属性和属性组：

```swift
#Index<Article>([\.type], [\.type, \.author])
```
