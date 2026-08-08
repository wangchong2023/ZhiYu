# Infrastructure 层问题驱动测试发现清单

> 测试以发现问题为目的。以下为审查 Infrastructure 层低覆盖率文件源码时发现的问题。
> 表格列：序号、问题描述、黑盒影响性、严重程度、修改方案、是否解决

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 是否解决 |
|------|----------|------------|----------|----------|----------|
| 1 | `StreamDeanonymizer.process` 截断分支（remaining.count >= maxRawLength）缓存 suffix(bufferSuffixLength) 时，若 `[` 在已输出的 prefix 部分，缓存的尾部不含 `[`，下次 process 找不到占位符开头，合法占位符被当普通文本输出，脱敏还原失败 | 流式对话中实体名称可能以 `[ENTITY_X]` 字面量形式泄露给用户（脱敏失效） | 🔴 P0 | 截断时应检查 `[` 是否在缓存区间内，若不在则全部输出不缓存；或改为查找最后一个 `[` 的位置决定缓存边界 | 是 |
| 2 | `ModelDownloadManager.verifySHA256` 空哈希跳过校验（`guard !expectedHash.isEmpty else { return true }`），未注册 checksum 时下载文件不校验完整性 | 下载的模型文件被中间人篡改，只要未注册 checksum 即通过校验并安装，用户得到损坏/恶意模型 | 🔴 P0 | 未注册 checksum 应视为校验失败（return false），而非跳过；或强制要求下载前必须注册 checksum | 是 |
| 3 | `ModelDownloadManager.cancelDownload` 用户主动取消设为 `.failed(error:)` 状态 | UI 无法区分"用户取消"和"真实失败"，用户自己取消却看到错误弹窗 | 🟡 P1 | DownloadState 新增 `.cancelled` 状态，cancelDownload 使用该状态 | 是 |
| 4 | `OnDeviceLLMService.generate` 模型输出 nil（generatedTextResult 为 nil）时 throw `modelNotLoaded`，但模型实际已加载 | 用户看到"模型未加载"错误，但模型确实已加载，误导用户重新加载而非检查模型输出问题 | 🟡 P1 | 新增 `OnDeviceError.emptyResponse` 错误类型，模型输出 nil 时抛出该错误 | 是 |
| 5 | `OnDeviceLLMService.chatOnDevice` 相关性匹配用 `query.contains(page.title)` 子串匹配 | 查询"历史"匹配所有标题含"历史"的页面，RAG 上下文注入大量无关内容，降低回答质量 | 🟡 P1 | 改用分词匹配或相似度评分，避免子串匹配误召回 | 是 |
| 6 | `PluginLoader.constantTimeCompare` 长度不等时提前 return false | 时序侧信道泄露签名长度信息，攻击者可缩小爆破空间 | 🟡 P1 | 长度不等时仍执行固定时长操作（如遍历较短者），最后再比较长度 | 是 |
| 7 | `PluginLoader.loadPluginFromRawJS` 裸 .js 文件 `isTrustedLocal: true` 跳过签名校验 | 用户将任意 .js 文件放入 Plugins 目录即可加载执行，恶意 JS 在沙箱内执行任意逻辑 | 🔴 P0 | 裸 .js 也要求签名，或至少限制为开发者模式 + 白名单路径 | 是 |
| 8 | `ChatLLMService.generate` 接收 maxTokens 参数但构建请求 body 时未包含该字段 | 调用方指定 maxTokens 限制生成长度，但实际请求未包含，模型使用默认值，Token 浪费 + API 费用增加 | 🟡 P1 | body 中添加 `LLMConstants.APIKey.maxTokens: maxTokens` | 是 |
| 9 | `ChatLLMService.chat` 未做 NER 脱敏（anonymize/deanonymize），直接把 query 发给云端 LLM | 用户输入的敏感信息（姓名、电话、邮箱）直接发送给云端 LLM API，隐私泄露风险 | 🔴 P0 | 对齐 ChatRunner.chat，添加 anonymize/deanonymize 流程 | 是 |
| 10 | `DatabaseManager.degradeToInMemory` 成功初始化内存数据库后，`state` 仍为 `.corrupted`（setup catch 块第 166 行设置），未恢复为 `.ready` 或新增 `.degraded` 状态 | 降级后 app 正常运行（内存数据库可用），但 UI 层持续显示"数据库损坏"警告，用户困惑：明明能用为何显示损坏？用户可能误以为数据丢失而清除 app | 🟡 P1 | `degradeToInMemory` 成功后将 `state` 更新为 `.ready`（或新增 `.degraded` 状态区分"真损坏"和"已降级"） | 是 |
