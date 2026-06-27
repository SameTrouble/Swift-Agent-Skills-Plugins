# Async/Await 基础

使用本文件当：

- 你刚开始使用 async/await 并需要基础模式。
- 你正在将基于回调的代码转换为 async/await。
- 你需要理解执行顺序和同步到异步的桥接。

跳过本文件如果：

- 你需要使用任务组或 `async let` 进行并行执行。使用 `tasks.md`。
- 你需要基于流的异步迭代。使用 `async-sequences.md`。

跳转到：

- 函数声明
- 执行顺序
- 使用 async let 并行执行
- URLSession 与 Async/Await
- 迁移策略

## 函数声明

用 `async` 标记函数以指示异步工作：

```swift
func fetchData() async -> Data {
    // 异步工作
}

func fetchData() async throws -> Data {
    // 可能失败的异步工作
}
```

**相比闭包的关键好处**：编译器强制返回值。不会遗忘完成处理程序。

> **课程深入**：此主题在 [Lesson 2.1: Introduction to async/await syntax](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 调用异步函数

### 从同步上下文

使用 `Task` 从同步桥接到异步：

```swift
Task {
    let data = try await fetchData()
}
```

### 从异步上下文

直接使用 `await`：

```swift
func processData() async throws {
    let data = try await fetchData()
    // 处理数据
}
```

## 执行顺序

结构化并发按你期望的顺序从上到下执行：

```swift
let first = try await fetchData(1)   // 等待完成
let second = try await fetchData(2)  // 在第一个完成后开始
let third = try await fetchData(3)   // 在第二个完成后开始
```

`await` 之后的代码仅在被等待的函数返回后执行。

> **课程深入**：此主题在 [Lesson 2.2: Understanding the order of execution](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 使用 async let 并行执行

使用 `async let` 并发运行多个操作：

```swift
async let data1 = fetchData(1)
async let data2 = fetchData(2)
async let data3 = fetchData(3)

let results = try await [data1, data2, data3]
```

### async let 如何工作

- **立即启动**：函数立即执行，甚至在 `await` 之前
- **结构化并发**：离开作用域时自动取消
- **错误处理**：如果一个失败，在等待分组结果时其他会被隐式取消
- **无冗余关键字**：不要在 `async let` 行本身使用 `try await`

```swift
// 冗余——避免
async let data = try await fetchData()

// 正确——在 await 点处理错误
async let data = fetchData()
let result = try await data
```

### 何时使用 async let

**使用当：**
- 任务不相互依赖
- 编译时已知任务数量
- 希望作用域退出时自动取消

**避免当：**
- 任务必须顺序运行
- 需要动态任务派生（使用 `TaskGroup`）
- 需要手动取消控制

### 限制

- 不能在顶层声明中使用（仅在函数体内）
- 未显式 await 的任务可能被隐式取消

> **课程深入**：此主题在 [Lesson 2.3: Calling async functions in parallel using async let](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## URLSession 与 Async/Await

URLSession 提供了基于闭包 API 的异步替代方案：

```swift
// 基于闭包（旧）
URLSession.shared.dataTask(with: request) { data, response, error in
    guard let data = data, error == nil else { return }
    // 处理响应
}.resume()

// Async/await（现代）
let (data, response) = try await URLSession.shared.data(for: request)
```

### 相比闭包的好处

- 无需解包可选的 `data` 或 `response`
- 自动错误抛出
- 编译器强制返回值
- 使用 do-catch 更简单的错误处理

### 完整网络请求模式

```swift
func fetchUser(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }
    
    return try JSONDecoder().decode(User.self, from: data)
}
```

### 带 JSON 的 POST 请求

```swift
func createUser(_ user: User) async throws -> User {
    let url = URL(string: "https://api.example.com/users")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(user)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }
    
    return try JSONDecoder().decode(User.self, from: data)
}
```

> **课程深入**：此主题在 [Lesson 2.4: Performing network requests using URLSession and async/await](https://www.swiftconcurrencycourse.com?utm_source=github&utm_medium=agent-skill&utm_campaign=lesson-reference) 中有详细介绍

## 类型化错误（Swift 6）

为更好的 API 契约指定确切错误类型：

```swift
enum NetworkError: Error {
    case invalidResponse
    case decodingFailed(DecodingError)
    case requestFailed(URLError)
}

func fetchData() async throws(NetworkError) -> Data {
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    } catch let error as URLError {
        throw .requestFailed(error)
    } catch {
        throw .invalidResponse
    }
}
```

调用方确切知道要处理哪些错误。

## 迁移策略

转换基于闭包的代码时：

1. **在旧方法旁边添加新 async 方法**——保持代码可编译
2. **更新方法签名**——添加 `async`，移除完成参数
3. **用 await 替换闭包调用**——使用 URLSession async API
4. **移除可选解包**——async API 返回非可选值
5. **简化错误处理**——使用 do-catch 而非嵌套闭包
6. **直接返回**——编译器强制返回值

## 常见模式

### 顺序执行（当顺序重要时）

```swift
let user = try await fetchUser(id: 1)
let posts = try await fetchPosts(userId: user.id)
let comments = try await fetchComments(postIds: posts.map(\.id))
```

### 并行执行（当独立时）

```swift
async let user = fetchUser(id: 1)
async let settings = fetchSettings()
async let notifications = fetchNotifications()

let (userData, settingsData, notificationsData) = try await (user, settings, notifications)
```

### 混合执行

```swift
// 先获取用户（下一步所需）
let user = try await fetchUser(id: 1)

// 然后并行获取相关数据
async let posts = fetchPosts(userId: user.id)
async let followers = fetchFollowers(userId: user.id)
async let following = fetchFollowing(userId: user.id)

let profile = Profile(
    user: user,
    posts: try await posts,
    followers: try await followers,
    following: try await following
)
```

## 进一步学习

有关 async/await 模式、错误处理策略和真实世界迁移场景的深入覆盖，请参见 [Swift Concurrency Course](https://www.swiftconcurrencycourse.com)。
