# 智宇 (ZhiYu) 插件开发指南

本文档为第三方开发者提供智宇插件生态的深度指导，涵盖底层原理、API 规范、全球化 (i18n) 以及与 Obsidian 的深度对标。

## 0. 插件架构与生命周期

```mermaid
flowchart TB
    subgraph 加载阶段[插件加载]
        ML[manifest.json 解析] --> VL[权限清单校验]
        VL --> JC[创建 JSContext]
        JC --> BR[注入 ZhiYu 桥接对象]
        BR --> OL[调用 onLoad]
    end

    subgraph 执行阶段[插件运行]
        OL --> RG[注册命令/视图/事件]
        RG --> PP[preProcess 内容拦截]
        RG --> PO[postProcess 渲染拦截]
        RG --> AI[requestAIAccess]
        RG --> FT[fetch 网络请求]
    end

    subgraph 安全守护[Watchdog 2.0]
        PP --> WD{500ms 竞速}
        WD -->|超时| KL[销毁 JSContext]
        KL --> BL[写入持久化黑名单]
        WD -->|正常| EX[继续执行]
    end

    subgraph 卸载阶段[插件卸载]
        EX --> OU[调用 onUnload]
        OU --> RC[资源释放]
        RC --> DM[从注册表移除]
    end
```

---

## 1. 核心架构原理 (Architecture)

智宇采用**受限沙箱隔离架构**。所有插件代码（`.js` 格式）均运行在系统原生的 `JavaScriptCore` 虚拟机中，与主程序物理隔离。

### 为什么选择 JavaScriptCore 而非 Node.js？
不同于 Obsidian (基于 Electron/Node.js)，智宇是一个**高性能原生应用**：
*   **安全性**：插件无法直接调用 OS API（如文件删除、静默联网），必须通过智宇定义的受限桥接对象 `ZhiYu` 进行。符合 Apple App Store 的沙盒审核要求。
*   **性能**：极轻量化，启动速度比 Electron 插件快 5-10 倍，且能充分利用 Apple 芯片的硬件加速。

---

## 2. API 参考 (Advanced JS API)

智宇提供了一套对标 Obsidian 的 API 集合，确保开发者能快速构建功能丰富的扩展。

| 扩展维度 | 智宇 (ZhiYu) JS API | 参数说明 |
| :--- | :--- | :--- |
| **日志** | `ZhiYu.log(msg)` | 在宿主控制台打印调试日志 |
| **全局指令** | `registerCommand(id, name, func)` | 注册到 `Cmd+K` 指令面板 |
| **侧边栏入口** | `registerRibbonItem(icon, title, func)` | 注册图标到侧边栏 Ribbon |
| **配置面板** | `registerSettingTab(name, schema, func)` | 支持通过 JSON Schema 自动渲染原生设置页 |
| **自定义视图** | `registerView(id, title, icon, func)` | 注册独立的侧边栏 Tab 功能页 |
| **系统事件** | `addEventListener(event, func)` | 监听 `onFileOpen`, `onPageSave` 等 |
| **持久化存储** | `saveData(key, value)` / `loadData(key)` | 为插件提供独立的私有存储空间 (Phase 2) |
| **安全网络** | `fetch(url, callback)` | 基于 `allowedDomains` 白名单发起请求 (Phase 1) |
| **AI 介入** | `requestAIAccess(prompt)` | 调用系统级大模型能力 (需权限) |
| **内容拦截** | `preProcess(content)` | 内容持久化前的实时修改钩子 |

---

## 3. 全球化与安全清单 (i18n & Security)

### 3.1 i18n manifest.json
智宇插件原生支持全球化。在 `manifest.json` 中使用字典结构定义多语言文本：

```json
{
  "id": "com.developer.cleaner",
  "version": "1.0.0",
  "author": "ZhiYu Team",
  "permissions": ["writeContent", "log"],
  "allowedDomains": ["api.example.com"],
  "names": {
    "en": "Smart Cleaner",
    "zh-Hans": "智能清洗器"
  },
  "descriptions": {
    "en": "Cleans redundant lines and optimizes Markdown.",
    "zh-Hans": "自动清理冗余空行并优化格式。"
  }
}
```

### 3.2 Security Watchdog (安全守护者)
为了保证宿主应用的流畅度，智宇实施了严格的**熔断机制**：
*   **物理挂起**: 如果插件在单次 Hook 中的执行时间超过 **500ms**（例如死循环），系统将立即物理挂起该插件，停止其后续所有回调。
*   **流量审计**: `fetch` 请求受 `allowedDomains` 白名单限制，防止数据非法外泄 (DLP)。

---

## 4. 如何开发 1 个插件：功能增强示例

以下示例展示了如何使用 **Phase 2 (存储)** 和 **Phase 3 (声明式 UI)** API：

```javascript
// AdvancedPlugin.js

function onLoad() {
    // 注册带 UI Schema 的设置面板
    const schema = [
        { "key": "isAutoSave", "type": "toggle", "label": "自动保存修改", "header": "通用配置" },
        { "key": "apiKey", "type": "text", "label": "第三方 API Key" }
    ];

    ZhiYu.registerSettingTab("增强配置", JSON.stringify(schema), "onConfigChanged");

    // 加载先前保存的数据
    const savedKey = ZhiYu.loadData("apiKey");
    ZhiYu.log("当前 API Key: " + (savedKey || "未设置"));
}

function onConfigChanged(updatedJson) {
    ZhiYu.log("用户修改了插件配置");
    // 如果提供了回调参数，可在此处理变更
}

function preProcess(content) {
    // 业务逻辑...
    return content;
}
```

---

## 5. 完整的模板拓扑 (Template Topology)

智宇插件采用统一的 `.zyplugin` 压缩包格式分发（本地安装与商店下载均使用此格式）。本质为 ZIP 归档，内部结构如下：

```text
plugin.zyplugin (ZIP 压缩包)
├── manifest.json      # 插件元数据与权限白名单声明
├── index.js           # 插件 JS 逻辑主入口文件 (JavaScriptCore 载入)
└── assets/            # 可选：图标、配图等静态资源
```

### 打包命令
```bash
# 将插件目录打包为 .zyplugin
cd my-zhiyu-plugin
zip -r ../my-plugin.zyplugin manifest.json index.js
```

### 安装方式
将 `.zyplugin` 文件放入 App 的 `Documents/Plugins/` 目录，App 启动时自动扫描并加载。兼容旧版裸 `.js` 脚本文件。

### 文件的协同关系
1. **`manifest.json`**：主 App 启动时，首先解析 manifest，静态核验权限列表（如 `requestAIAccess`、`fetch` 等）和 `allowedDomains` 域名白名单。
2. **`index.js`**：宿主应用为该插件创建独立的 JSVirtualMachine 和 JSContext，物理载入 `index.js`，并注入受限的宿主 `ZhiYu` 桥接对象。
3. **`styles.css`**：如果插件注册了自定义 WebView 渲染视图，宿主会将 `styles.css` 以 `<style>` 标签形式动态注入到渲染 DOM 容器中。

---

## 6. 局域网调试与真机实时热重载 (Live Reload)

为了给第三方开发者提供极致的 DX (Developer Experience)，智宇提供了一套局域网无线实时热重载工具集。

### 6.1 本地测试服务器 (CLI Dev Server)
在您的插件开发文件夹下，可以使用智宇开发者命令行工具启动热重载服务：

```bash
# 安装智宇插件 CLI 开发工具
npm install -g @zhiyu/plugin-cli

# 启动开发服务器，这会在局域网内开启 Websocket 监听服务 (默认 9091 端口)
zhiyu-cli dev --port 9091
```

### 6.2 真机实时连接与热重载流
1. 打开 iPhone/macOS 智宇主程序的 **“设置 -> 开发者选项 -> 插件无线调试”**。
2. 输入局域网开发服务器地址（例如 `ws://192.168.1.100:9091`），点击 **连接**。
3. **建立连接 (Handshake)**：主 App 将通过 Websocket 与本地 CLI 服务器握手，并下载当前开发中的插件元数据。
4. **实时热重载 (Live Reload)**：
   * 当您在本地编辑器中修改 `index.js` 或 `manifest.json` 并保存时，CLI 工具会感知文件系统变更，自动通过 Websocket 触发推送。
   * 宿主主 App 收到更新后，会物理销毁旧的 `JSContext` 实例，瞬间重建全新的执行环境，并热重载最新的 JS 逻辑，**无需重新构建或重启主 App**。
5. **Console 日志重定向**：
   * 插件中调用的 `ZhiYu.log(msg)`，会通过 Websocket 管道被实时传输并打印在开发机的 CLI 控制台中，实现“腕上运行，机上调试”。
