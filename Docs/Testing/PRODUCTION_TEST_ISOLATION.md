# 生产与测试宿主隔离整改

关联台账：`TEST_DRIVEN_FINDINGS.md` 第 74 项。状态：**整改中，未验收关闭**。

## 目标与结构

正式 iOS/macOS 应用由 `ProductionAppLauncher` 启动，复用 `ZhiYuApp` 场景。不解析测试启动参数，不根据 XCTest 类存在与否改变生命周期。

| Target | 模块 | 入口 | 用途 |
|--------|------|------|------|
| ZhiYu | ZhiYu | ProductionAppLauncher | 正式 iOS 应用 |
| ZhiYuMac | ZhiYuMac | ProductionAppLauncher | 正式 macOS 应用 |
| ZhiYuUnitTestHost | ZhiYuUnitTestHost | UnitTestHostApp | iOS 空单测宿主 |
| ZhiYuMacUnitTestHost | ZhiYuMacUnitTestHost | UnitTestHostApp | macOS 空单测宿主 |
| ZhiYuUITestHost | ZhiYuUITestHost | UITestHostLauncher | iOS UI 测试应用 |
| ZhiYuMacUITestHost | ZhiYuMacUITestHost | UITestHostLauncher | macOS UI 测试应用 |

各应用模块名必须独立，防止同时构建时生成同名 `.swiftmodule`、`.abi.json` 和 `.swiftsourceinfo`。单元测试通过 `@testable import` 导入独立宿主模块。平台应用模板共用业务源码和包依赖，测试入口位于 `Tests/Host/`，测试支持位于 `Tests/TestSupport/`。

UI 测试的 Target Application 指向对应测试宿主，`XCUIApplication()` 不再硬编码正式 macOS bundle ID。正式 target 不包含任何宿主入口或测试支持源码，也不嵌入测试应用。

## 状态及存储边界

- UI 测试应用使用 `top.izhiyu.testing.*` bundle ID，无正式 App Group entitlement。
- 测试数据库策略先于路径解析和旧库迁移执行，直接建立独立的内存主库、全局库。
- 笔记本及导入文件路径可由 `ApplicationStorageLocation` 注入，每次 UI 测试应用启动使用独立临时目录。
- 无真实访问凭据时，UI 测试使用仅驻留内存的 Keychain 替身，避免触碰系统钥匙串。真实后端验收使用系统 Keychain。
- 测试 Keychain service 由测试应用 bundle ID 派生；正式服务保留已有命名空间，避免丢失既有会话。
- 重置认证、Token 写入、游客会话、闪屏及引导状态准备只在测试入口执行。
- Token 写入失败直接终止测试应用启动，禁止静默退化为游客。
- 测试布局、自动登录及播种策略在创建任何业务环境之前安装。
- 显式离线 UI 测试通过测试侧配置及 `UITestChatService` 提供响应，生产 LLM 门面不识别测试参数。

空单测宿主不创建 `AppEnvironment`。需要环境的测试显式使用 `TestAppEnvironment`，选择内存存储和不启动后台服务的实例。

## 门禁

`check-code-test-coupling.py --strict` 与 `audit-debug-in-sources.py --strict` 同时扫描主应用及六个本地包的生产源码，不扫描第三方 checkout、构建产物或独立 TestMocks target。

正式入口与平台目录不再整文件豁免测试耦合。条件编译使用栈识别嵌套及 `#elseif DEBUG`。预览豁免仅检查首个有效语句；获准记录日志的文件仍检查测试逻辑。

两项检查均接入 Xcode 构建总门禁，DEBUG 检查补入 `make audit`。`Tools/Tests/test_production_isolation.py` 验证门禁边界、target 源码归属、独立模块名、空单测宿主以及 UI 目标。

## 验证记录

| 项目 | 当前结果 |
|------|----------|
| 工程生成 | `make gen` 通过 |
| 门禁及 target 成员关系 | 14 项 Python 回归检查通过 |
| UFPCore | 374 项测试通过 |
| UFPStorage | 89 项测试通过 |
| 生产 iOS Debug 构建 | Xcode BuildProject 通过，日志时间 2026-11-22 22:57 |
| iOS 单测宿主与完整单测 bundle | Xcode BuildProject 构建通过，相关 51 项回归全部通过、无跳过 |
| iOS/macOS UI 测试 | 待运行 |
| 真实后端认证 | 未配置真实访问 Token，未完成验收 |
| 运行时存储隔离 | 待宿主/UI 测试验证，静态成员及配置检查已通过 |
| SonarQube Quality Gate | 未取得服务器验收结果，不宣称覆盖率或质量门禁达标 |

SwiftPM 在当前受限环境内调用嵌套 `sandbox-exec` 会失败；上述包测试使用 `make test-spm PKG=<包名> SWIFT_TEST_FLAGS=--disable-sandbox` 运行。

## 运行入口

- 单测：`make test-unit`，scheme 为 `ZhiYuUnitTests`。
- iOS UI：`make test-ui`，scheme 为 `ZhiYuUITests`。
- macOS 单测/UI：分别选择 `ZhiYuMacUnitTests`、`ZhiYuMacUITests` scheme。
- 隔离门禁回归：`python3 -m unittest discover -s Tools/Tests -v`。

真实后端测试从测试 runner 的环境读取以下配置，凭据不得提交或写入报告：

| 环境变量 | 用途 |
|----------|------|
| ZHIYU_UI_TEST_ACCESS_TOKEN | 预先取得的真实后端访问 Token |
| ZHIYU_UI_TEST_EXPECTED_NICKNAME | 该账户在后端的预期昵称 |
| ZHIYU_UI_TEST_BACKEND_URL | 与应用配置相同的受信任测试网关 |
| ZHIYU_UI_TEST_EXPECTED_PLAN | 后端预置的预期套餐标识 |

缺少配置显示明确跳过；提供配置后认证失败必须断言失败。跳过不计为验收通过。订阅用例验证真实接口响应，不能替代应用订阅页面的完整端到端验收。

所有验收项通过前，第 74 项保持整改中。
