# 参数化测试

用单个测试函数测试多个输入。

## 基本参数化

```swift
@Test(arguments: [1, 2, 3, 4, 5])
func isPositive(number: Int) {
    #expect(number > 0)
}
```

## 多个参数

### 使用 zip（配对）

```swift
@Test(arguments: zip(
    ["hello", "world", "test"],
    [5, 5, 4]
))
func stringLength(string: String, expectedLength: Int) {
    #expect(string.count == expectedLength)
}
```

### 笛卡尔积（所有组合）

```swift
@Test(arguments: [1, 2], ["a", "b"])
func combinations(number: Int, letter: String) {
    // 运行 4 次：(1,a), (1,b), (2,a), (2,b)
    #expect(!"\(number)\(letter)".isEmpty)
}
```

## 自定义测试用例

```swift
struct ValidationTestCase {
    let input: String
    let isValid: Bool
    let description: String
}

extension ValidationTestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

let validationCases = [
    ValidationTestCase(input: "valid@email.com", isValid: true, description: "valid email"),
    ValidationTestCase(input: "invalid", isValid: false, description: "missing @"),
    ValidationTestCase(input: "", isValid: false, description: "empty string"),
]

@Test(arguments: validationCases)
func validateEmail(testCase: ValidationTestCase) {
    let result = EmailValidator.validate(testCase.input)
    #expect(result == testCase.isValid)
}
```

## 枚举用例

```swift
enum Environment: CaseIterable {
    case development, staging, production
}

@Test(arguments: Environment.allCases)
func configurationLoads(environment: Environment) {
    let config = Configuration(environment: environment)
    #expect(config.isValid)
}
```

## 范围

```swift
@Test(arguments: 1...100)
func withinRange(value: Int) {
    #expect(value >= 1 && value <= 100)
}
```

## 元组集合

```swift
@Test(arguments: [
    ("2024-01-15", true),
    ("invalid", false),
    ("2024-13-45", false),
])
func dateValidation(dateString: String, shouldBeValid: Bool) {
    let isValid = DateValidator.validate(dateString)
    #expect(isValid == shouldBeValid)
}
```

## 避免笛卡尔积爆炸

小心使用多个参数列表：

```swift
// 警告：这会运行 1000 次（10 x 10 x 10）
@Test(arguments: 1...10, 1...10, 1...10)
func tooManyTests(a: Int, b: Int, c: Int) { }

// 更好：使用 zip 进行配对测试
@Test(arguments: zip(zip(inputs1, inputs2), expectedResults))
func pairedTest(inputs: ((Int, Int), Int)) { }
```

## 过滤参数

```swift
let testCases = (1...100).filter { $0 % 10 == 0 }

@Test(arguments: testCases)
func multiplesOfTen(value: Int) {
    #expect(value % 10 == 0)
}
```

## 复杂测试数据

```swift
struct APITestCase: Sendable {
    let endpoint: String
    let method: HTTPMethod
    let expectedStatus: Int
    let body: Data?

    static let cases: [APITestCase] = [
        APITestCase(endpoint: "/users", method: .get, expectedStatus: 200, body: nil),
        APITestCase(endpoint: "/users", method: .post, expectedStatus: 201, body: validUserData),
        APITestCase(endpoint: "/users/999", method: .get, expectedStatus: 404, body: nil),
    ]
}

@Test(arguments: APITestCase.cases)
func apiEndpoint(testCase: APITestCase) async throws {
    let response = try await client.request(
        endpoint: testCase.endpoint,
        method: testCase.method,
        body: testCase.body
    )
    #expect(response.statusCode == testCase.expectedStatus)
}
```

## 最佳实践

1. **保持测试用例聚焦**：每个用例只测试一件事
2. **使用描述性名称**：实现 `CustomTestStringConvertible`
3. **避免笛卡尔积**：配对数据使用 zip
4. **分组相关用例**：为复杂场景创建结构体
5. **使测试数据 Sendable**：并行执行所需

```swift
// 好：清晰、配对的测试用例
@Test(arguments: zip(["a", "ab", "abc"], [1, 2, 3]))
func stringLength(string: String, expected: Int) {
    #expect(string.count == expected)
}

// 坏：笛卡尔积，意图不明确
@Test(arguments: ["a", "ab", "abc"], [1, 2, 3])
func unclearTest(string: String, number: Int) { }
```
