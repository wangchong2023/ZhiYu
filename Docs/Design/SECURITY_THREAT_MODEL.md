# 智宇 (ZhiYu) 安全威胁模型与响应规范 (Security Threat Model)

**版本**：2.0  
**作者**：安全与隐私架构组  
**日期**：2026-05-20  

---

## 1. 概述与设计原则

智宇作为一款 AI 原生的知识管理应用，处理大量涉及个人隐私、密钥和知识产权的数据。本威胁建模遵循以下核心原则：
*   **零信任架构 (Zero Trust)**：默认不信任任何外来输入、非签名插件以及网络连接。
*   **最小特权 (Least Privilege)**：对插件沙盒及外部挂载的本地文件夹权限实行随用随取，用完即弃。
*   **Defense in Depth (深度防御)**：防线从 OS 沙盒、生物识别，延伸到应用层加密和 RAG 提示词过滤。

---

## 2. 基于 STRIDE 模型的威胁矩阵

系统整体面临的威胁按照 STRIDE 分类并映射至具体防御策略：

| 威胁类别 | 威胁编号 | 物理/逻辑边界 | 具体威胁描述 | 防御/控制手段 | 验证手段 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **S** (Spoofing 欺骗) | T-S-01 | 生物识别 / 密码验证 | 攻击者在设备解锁状态下，尝试通过拦截本地服务调用伪造“已授权”状态。 | 依赖 Apple LocalAuthentication，并在内存中对 `AuthService` 执行严格的严格并发隔离保护，防止越权状态被仿冒。 | [TC-VLT-05] 伪造未授权状态访问接口单元测试。 |
| **T** (Tampering 篡改) | T-T-01 | 外部挂载目录 / 物理多库 | 恶意用户或外部进程直接修改挂载目录下的物理数据库或 Markdown 文件内容。 | 1. 引入文件级 SHA256 指纹校验机制；<br>2. 应用层字段级别进行 AES-256-GCM 加密，外部篡改会导致解密失败。 | `SecurityIntegrityTests.swift` 验证指纹失效异常。 |
| **R** (Repudiation 否认) | T-R-01 | 插件执行审计 | 恶意插件悄悄修改了笔记本内容，而系统没有相关操作记录。 | 所有通过 `PluginContext` 执行的写入、API 调用均由 `PluginRegistry` 的全局 Logger 强制进行流水审计落盘。 | 检查 `PluginSandboxTests` 中的操作流水日志生成。 |
| **I** (Info Disclosure 泄露) | T-I-01 | SQLite 物理数据库落盘 | 设备被物理拷贝或越狱，SQLite 存储的文件以明文暴露敏感隐私数据。 | 1. 核心字段（正文、摘要等）在落盘前经过 `SecurityManager` 配合 Keychain 密钥的 AES-256-GCM 应用层加密；<br>2. 系统使用独立且严格隔离的多笔记本物理存储目录。 | 检索导出的数据库，检查原始密文在非授权状态下不可读。 |
| **I** (Info Disclosure 泄露) | T-I-02 | 插件沙箱越权 | 第三方 JS 插件通过网络请求或文件 API 将用户的隐私知识库内容向外传输。 | JavaScriptCore 容器彻底剥离 OS 级 `fetch`、`XHR`、`fs` 等接口；插件网络调用必须通过 `PluginContext.requestAIAccess` 申报并受限流阻断保护。 | `PluginSandboxTests` 验证沙箱限制。 |
| **D** (Denial of Service 拒绝服务) | T-D-01 | AI 客户端调用 | 恶意插件或循环逻辑疯狂发起大模型问答，撑爆 API 额度或导致客户端 CPU 挂起。 | 引入 **Plugin Watchdog 2.0 机制**：限制单次 AI 交互执行时长，单次 JS 宏限制 500ms 竞速超时，超期自动 Kill 虚拟机。 | `PluginSandboxTests` 中的死循环虚拟机强杀测试。 |
| **E** (Elevation of Privilege 越权) | T-E-01 | AI Prompt 注入 | 文档中暗含恶意攻击性 Prompt，在 RAG 管道召回后，误导大模型输出或执行敏感越权指令。 | 1. `LLMContextBuilder` 采用安全沙箱包装，隔离“上下文”与“系统指令”；<br>2. `PromptSanitizer` 过滤潜在的系统提示词越狱关键字。 | `RAGPipelineTests` 中的指令注入抵抗用例。 |
| **I** (Info Disclosure 泄露) | T-I-03 | 本地会话凭证存储 | 攻击者越狱设备，试图读取沙盒本地保存的 Access/Refresh Token 以窃取会话。 | Token 并不落盘于普通数据库或 UserDefaults，而是严格托管于系统级硬件安全容器 Keychain 中，只允许当前签名证书访问。 | 单元测试验证 UserDefaults 内无法解析到会话 Token。 |
| **S** (Spoofing 欺骗) | T-S-02 | 刷新 Token 传输与重放 | 攻击者拦截已过期的 Access Token 刷新包，并尝试重放旧的 Refresh Token 换取新令牌。 | 1. 强制全网 TLS 1.3/HTTPS 加密传输；<br>2. 后端对 /api/v1/auth/refresh 实施 Token Rotation（一次性轮转，刷新即作废旧 Refresh Token）。 | 验证旧 Refresh Token 两次调用 refresh 接口会抛出 40103 异常。 |
| **S** (Spoofing 欺骗) | T-S-03 | 长期记住登录会话劫持 | 会话已在后端被注销，但由于客户端持有长效 Token，在无网或未校验状态下仍能进入工作区。 | 客户端冷启动时在 SplashView 阶段发起 GET /api/v1/auth/user/profile 静默校验。一旦发现过期或不可用，立即触发 .userAuthExpired 广播强退。 | 验证在 Token 失效状态下冷启动 App 无法跳过登录面板。 |

---

## 3. SQLite 应用层落盘加密设计

为了在不产生大幅查询开销的前提下保障离线数据安全，系统采用 **应用层字段级加密** 与 **多库物理隔离** 的双重设计：

```
                    ┌───────────────────────────────────┐
                    │      KnowledgePage (内存明文)      │
                    └─────────────────┬─────────────────┘
                                      │
                                      ▼
                        SecurityManager.shared.encrypt
                      AES-256-GCM + Keychain Master Key
                                      │
                                      ▼
                    ┌───────────────────────────────────┐
                    │      Encrypted Payload (密文)      │
                    └─────────────────┬─────────────────┘
                                      │
                         写入物理对应笔记本的沙盒目录
                                      ▼
                    ┌───────────────────────────────────┐
                    │  vaultA.sqlite3 / vaultB.sqlite3  │
                    └───────────────────────────────────┘
```

*   **Keychain 密钥托管**：每次生成笔记本金库时，系统生成一个高熵随机密钥存入系统 Keychain 容器，只可通过硬件生物识别（FaceID/TouchID）恢复。
*   **AES-GCM 加密字段**：`content` (主正文), `rawTextSnippet` (切片片段), `summary` (AI 合成摘要)。
*   **明文保存字段**（用于 FTS5 搜索辅助，只存储非隐私脱敏的辅助索引）：`tags`, `pageType` 等元数据。

---

## 4. 插件沙箱 (JavaScriptCore) 安全边界

智宇的插件引擎运行于原生 JavaScriptCore 环境中，通过**空气墙（Air-gap）**策略切断外部资源访问：

1.  **无环境全局对象**：`window`, `document`, `XMLHttpRequest`, `fetch`, `WebSocket`, `global` 被完全擦除。
2.  **受控桥接 (`PluginContext`)**：插件必须显式调用原生桥接口。
3.  **权限最小声明**：
    ```json
    {
      "name": "Concept AutoLinker",
      "permissions": ["readContent", "network"],
      "networks": false
    }
    ```
4.  **CPU 竞速守护**：主线程起用 500ms 超时限制，一旦插件逻辑未能在指定时间内返回或抛出异常，`PluginRegistry` 立即强行销毁该虚拟环境。

---

## 5. 应急响应与灾备流程

1.  **自动熔断**：一旦系统检测到 Master Key 解密数据库连续失败 5 次以上，或者指纹 HMAC 严重校验失败，`SecurityManager` 将立即冻结该金库句柄，并将 UI 重定向到强制锁屏状态。
2.  **只读回滚**：当本地磁盘发生权限撤销（如 iCloud 同步被外部强制下线）时，系统自动切换为“纯本地只读挂载”模式，禁止进一步写入损坏物理文件。
3.  **本地备份导出**：提供主密码保护下的离线物理导出机制，数据打包为 AES 容器格式，用户可在任何平台离线还原。
