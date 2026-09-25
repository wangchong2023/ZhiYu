# 智宇 (ZhiYu) 安全规范与隐私架构 (Security & Privacy Spec)

本文档阐述了智宇系统的安全设计原则、数据隔离机制及隐私保护措施。

## 0. 安全架构总览

```mermaid
flowchart TB
    subgraph 数据隔离层[1. 数据隔离 Sandbox & Isolation]
        FA[文件访问控制<br/>Security-Scoped Bookmarks]
        PS[插件沙盒隔离<br/>Watchdog 500ms + 黑名单]
        PE[插件存储加密<br/>AES-256-GCM]
    end

    subgraph 隐私保护层[2. 隐私保护 Privacy Protection]
        PM[隐私模式<br/>#private 高斯模糊]
        LE[离线优先向量化<br/>Apple NLEmbedding]
    end

    subgraph 金库安全层[3. 金库加锁 Vault Locking]
        VL[物理锁定<br/>SQLite 连接关闭]
        BI[生物识别<br/>FaceID / TouchID]
    end

    subgraph 审计层[4. 安全审计 Audit Logs]
        AL[操作审计<br/>LogService 不可篡改]
    end

    subgraph LLM 安全层[5. LLM 安全 LLM Security]
        PI[Prompt 注入防御<br/>正则过滤 + 隔离执行]
        MD[元数据阻断<br/>#private 内容隔离]
    end

    数据隔离层 --> 隐私保护层
    隐私保护层 --> 金库安全层
    金库安全层 --> 审计层
    审计层 --> LLM 安全层
```

---

## 1. 数据隔离架构 (Sandbox & Isolation)

智宇严格遵循 **Apple Sandbox** 规范，并实施了以下内部隔离策略：

### 1.1 文件访问控制 (Scoped Access)
- **书签持有机制**：所有挂载的外部文件夹（Vault）均通过 `Security-Scoped Bookmarks` 进行权限持有。
- **最小特权原则**：应用仅在需要扫描或同步时开启安全域访问，完成后立即通过 `stopAccessingSecurityScopedResource` 释放。

### 1.2 插件沙盒隔离 (Plugin Sandbox)
- **物理回收机制 (Watchdog 2.0)**：所有插件 Hook 执行受到 **500ms 竞速观察**。一旦超时，宿主直接销毁该 `JSContext` 物理实例，并将其 ID 写入 **UserDefaults 持久化黑名单**，防止僵尸插件在重启后循环消耗 CPU。
- **权限清单**：插件必须在 `manifest.json` 中明确声明所需的权限（如网络访问、LLM 读写）。未声明的动作将被系统核心逻辑拦截。
- **DLP 网络审计**：插件的 `fetch` 请求受 `allowedDomains` 白名单管控。只有在元数据中预先报备并获得用户授权的域名才允许通信。
- **数据大小限制**：沙箱层强制限制插件单次返回内容大小（如 5MB），防止内存溢出攻击。

### 1.3 插件存储加密 (Encrypted Storage)
- **密钥隔离**：每个插件的数据以 `pluginID` 命名的独立 JSON 存储。
- **全盘加密**：写入磁盘前均通过 **AES-256-GCM** 进行全盘加密，解密密钥派生自设备系统级的 Keychain。即使设备物理丢失，第三方也无法通过越权读取 `.json` 文件获取插件内的敏感配置（如三方 API Key）。

---

## 2. 隐私保护机制 (Privacy Protection)

### 2.1 隐私模式 (Privacy Mode)
- **判定逻辑**：系统自动识别带有 `#private` 标签或 `private` 标记的知识节点。
- **渲染模糊**：在“隐私模式”开启时，系统会在 UI 渲染层对敏感内容应用 12px 的高斯模糊，必须通过生物识别或手动点击解锁方可查看。

### 2.2 离线优先向量化 (Local Embedding)
- **本地推断**：默认使用本地向量模型（Apple Neural Engine 加速），确保用户的知识片段不会上传至第三方云端进行向量化。
- **传输加密**：若用户选择使用 OpenAI 等云端模型，所有数据通过 HTTPS 传输，且不持久化于云端缓存。

---

## 3. 金库加锁 (Vault Locking)

### 3.1 物理锁定
- **数据库冻结**：当金库处于锁定状态时，`SQLiteStore` 会关闭所有连接句柄，并清除内存缓存。
- **生物识别集成**：集成 FaceID / TouchID。只有验证通过后，才会重新加载数据库加密密钥。

---

## 4. 安全检查 (Audit Logs)

- **操作审计**：所有敏感操作（如删除金库、修改安全设置、导出数据）均会记录在本地操作日志中（`LogService`），无法被插件篡改。

---

## 5. LLM 安全 (LLM Security)

### 5.1 Prompt 注入防御 (Prompt Injection Defense)
- **输入清洗**：所有传入 LLM 的用户输入均经过正则过滤，移除潜在的系统指令劫持关键词（如 "Ignore all previous instructions"）。
- **隔离执行**：AI 任务（如 Summary, Quiz）在独立进程/上下文中执行，且无权修改核心数据库状态，除非经过 `AppStore` 显式写入。
- **元数据阻断**：AI 无法获取标记为 `#private` 且未通过生物识别验证的内容。

---

## 6. 会话安全与令牌存储 (Session Security & Keychain Storage)

- **物理沙盒托管**：普通用户的登录凭据（Access Token 与长效 Refresh Token）完全托管于 iOS/macOS 物理系统安全区 Keychain 中，严禁落入冷存储数据库或 UserDefaults，杜绝应用沙盒泄漏导致的会话失窃。
- **Token 轮转刷新 (Rotation)**：每次刷新操作完成后，旧的 Refresh Token 均会被拉入 Redis 黑名单作废，降低拦截重放风险。
- **无感自动校验**：冷启动时，应用使用安全区内的 Token 自动校验本地 Session。若发生 401 鉴权失效，系统将通过 Refresh Token 完成静默换取新令牌；一旦彻底失效，立即清空本地 Keychain 安全凭据并退回到登录面板，保障本地终端会话安全。
