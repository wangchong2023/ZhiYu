# 开源致谢与法律合规 (Acknowledgments)

智宇 (ZhiYu) 的卓越体验离不开以下开源项目与技术的支持。

## 1. Swift Package Manager 直接依赖

| 库 | 许可证 | 用途 |
|------|------|------|
| [GRDB](https://github.com/groue/GRDB.swift) | MIT | SQLite + FTS5 全文搜索，高性能本地知识库存储 |
| [Lottie](https://github.com/airbnb/lottie-ios) | Apache 2.0 | JSON 驱动的动画渲染引擎 |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | MIT | ZIP 归档文件的创建与解压 |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | Apache 2.0 | Apple 官方 Markdown 解析器，块级语法解析 |
| [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | MIT | SwiftUI 原生 Markdown 渲染组件 |
| SwiftJSONSanitizer | MIT | JSON 清洗与安全解析（离线 vendored，`opensrc/swift/`） |
| PartialJSON | Apache 2.0 | 流式部分 JSON 解析（离线 vendored，`opensrc/swift/`） |
| [GoogleSignIn](https://github.com/google/GoogleSignIn-iOS) | Apache 2.0 | Google 账号 OAuth 登录 |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | MIT | 快照测试框架（仅测试依赖） |

## 2. Swift Package Manager 传递依赖

| 库 | 许可证 | 说明 |
|------|------|------|
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Apache 2.0 | Swift 语法解析库（swift-markdown 依赖） |
| [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) | MIT | 调试输出美化（swift-snapshot-testing 依赖） |
| [xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay) | MIT | XCTest 动态覆盖层（swift-snapshot-testing 依赖） |

## 3. 本地 Framework 依赖

| Framework | 许可证 | 用途 |
|------|------|------|
| WechatOpenSDK | 腾讯 EULA | 微信登录 OAuth |
| ATAuthSDK | 阿里云 EULA | 运营商一键登录 |

## 4. Apple 系统框架

- **SQLite3**：高性能本地知识库存储
- **Natural Language Framework**：CJK 智能分词与实体提取
- **Core ML + Neural Engine**：端侧大模型本地推理
- **Metal / SwiftUI**：3D 知识图谱的高帧率渲染
- **CloudKit**：跨设备数据同步

## 5. 算法与方法论

- **RecursiveChunker**：基于递归下降的长文本分块策略
- **LWW (Last Write Wins)**：分布式冲突解决核心算法
- **两阶段行内解析算法**：智宇自研，保护 `[[双链]]` 不被正则贪婪匹配破坏

## 6. 字体与设计

- **Inter / Outfit (Google Fonts)**：提供系统的高级美感排版
- **SF Symbols**：提供高度一致的交互图标

---
*本项目遵循 MIT 协议。任何第三方插件在调用内核 API 时，均需遵守 智宇 (ZhiYu) 插件安全准则。*
