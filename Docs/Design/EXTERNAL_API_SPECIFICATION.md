# 智宇 (ZhiYu) 对外 RESTful API 接口规范文档

本文档定义了智宇 (ZhiYu) AI 原生知识管理系统对外暴露的标准 RESTful HTTP API 接口规范。供前端应用（iOS / macOS Catalyst / watchOS）、客户端 SDK 以及第三方开发者集成参考。

---

## 一、 通用约定与规范

### 1.1 服务域名与基础路径 (Base URL)
- **生产环境 Base URL**：`https://api.zhiyu.app`
- **沙盒/测试环境 Base URL**：`https://staging-api.zhiyu.app`

### 1.2 鉴权机制 (Authentication)
对于需要身份认证的接口，客户端必须在 HTTP 请求头中携带 Bearer Token：
```http
Authorization: Bearer <your_access_token>
```
Token 可通过登录接口或刷新 Token 接口获取。

### 1.3 内容类型 (Content-Type)
- 普通请求/响应格式：`application/json; charset=utf-8`
- 文件上传请求格式：`multipart/form-data`
- 大文件/权重拉取：`application/octet-stream` (支持 HTTP `Range` 头断点续传)

### 1.4 通用响应格式 (Standard Response Structure)
所有 JSON 接口返回统一的数据封装：

```json
{
  "code": 200,
  "message": "success",
  "data": { ... },
  "timestamp": 1784724059
}
```

### 1.5 常见状态码与错误码

| HTTP Status | 业务 code | 描述说明 |
| :--- | :--- | :--- |
| `200 OK` | `200` | 请求处理成功 |
| `400 Bad Request` | `40001` | 请求参数检验失败或缺失 |
| `401 Unauthorized` | `40101` | Token 无效、已过期或未提供 Authorization 头 |
| `403 Forbidden` | `40301` | 权限不足（如非 Pro 订阅用户尝试访问高级 AI 权益） |
| `404 Not Found` | `40401` | 请求的资源不存在 |
| `429 Too Many Requests` | `42901` | 请求频率超出限制 (Rate Limit) |
| `500 Internal Error` | `50001` | 服务器内部故障 |

### 1.6 对外 API 接口全景汇总表

下表汇集了智宇 (ZhiYu) 系统中所有对外 RESTful API 接口的全景视图，方便架构师与开发者快速查阅与对接：

| 业务模块 | 接口名称 | 核心作用与描述 | 请求方法 & URI | 发起方 (Caller) | 提供方 (Provider) | 注意事项与安全约束 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **账号与资料** | 获取用户 Profile | 拉取当前登录用户的完整资料与全局权限状态 | `GET /api/v1/user/profile` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；用于自动登录恢复及 Token 刷新后同步态 |
| **账号与资料** | 更新个人资料 | 修改用户显示昵称、头像 URL、性别及生日 | `PUT /api/v1/user/profile` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；Mock 模式下仅同步更新本地内存缓存 |
| **账号与资料** | 上传用户头像 | 上传二进制头像图片并返回存储 OSS 访问地址 | `POST /api/v1/user/profile/avatar` | 智宇 App 客户端 | 智宇后端 API / OSS | 需 `Bearer Token`；`multipart/form-data`，图片限制 5MB 内 |
| **账号与资料** | 账号登录与注册 | 支持密码登录或手机短信验证码一键注册登录 | `POST /api/v1/auth/login` | 智宇 App 客户端 | 智宇后端 API 服务 | 响应返回 AccessToken 与 RefreshToken，自动存入 Keychain |
| **账号与资料** | 发送短信验证码 | 向目标手机号下发登录/重置密码所需的验证码 | `POST /api/v1/auth/sms/send` | 智宇 App 客户端 | 智宇后端 API / 短信网关 | 限制单 IP 及手机号高频触发，防止恶意短信接口刷量 |
| **账号与资料** | 第三方 OAuth 登录 | 整合 Apple/微信/Google/GitHub/运营商免密登录 | `POST /api/v1/auth/oauth/{provider}` | 智宇 App 客户端 | 智宇后端 API 服务 | 需要提交第三方平台签发的 Authorization Code / ID Token |
| **账号与资料** | 刷新 Access Token | 当访问 Token 过期时利用 RefreshToken 换取新凭证 | `POST /api/v1/auth/refresh` | 智宇 App 客户端 | 智宇后端 API 服务 | 客户端 HTTP 网络拦截器检测到 `401` 时自动无感触发 |
| **账号与资料** | 退出登录 | 注销并吊销服务端的 RefreshToken 凭证 | `POST /api/v1/auth/logout` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；同步清空 Keychain 中的本地密钥存储 |
| **订阅与套餐** | 查询订阅套餐列表 | 获取 Lite / Pro / Team 各级别套餐定价与权益配额 | `GET /api/v1/subscriptions/plans` | 智宇 App 客户端 | 智宇后端 API 服务 | 公开接口；用于收银台/付费墙/升级引导界面的展示 |
| **订阅与套餐** | 查询当前用户订阅 | 拉取当前登录用户生效的套餐类型、到期日与限额 | `GET /api/v1/subscriptions/me` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；用于客户端控制 Vaults/Pages/Plugins 额度 |
| **订阅与套餐** | 验证 Apple 购买凭证 | 校验 App Store StoreKit 内购收据并激活 Pro | `POST /api/v1/subscriptions/apple/verify` | 智宇 App 客户端 | 智宇后端 API / Apple Verify | 需 `Bearer Token`；服务器二次校验成功后刷新本地 Profile |
| **应用改进** | 提交通用反馈改进 | 上报 Bug 缺陷、功能建议及体验改善工单 | `POST /api/v1/feedback/submit` | 智宇 App 客户端 | 智宇后端 API 服务 | 本地 SQLite 优先持久化，联网时通过后台任务静默异步同步 |
| **AI 对话评测** | 发送对话结果反馈 | 提交某条 AI 问答消息的点赞/点踩满意度与评语 | `POST /api/v1/ai/chat/feedback` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；用于 RAG 检索模型调优与回答质量迭代 |
| **AI 对话评测** | 发送 RAG 质量评估 | 上报 LLM-as-a-Judge 的 7 维 Benchmark 测评指标 | `POST /api/v1/ai/rag/evaluation` | 智宇 App 客户端 | 智宇后端 API 服务 | 需 `Bearer Token`；包含忠实度、幻觉率、引用准确度等 7 维分值 |
| **大模型管理** | 查询推荐模型目录 | 拉取云端端侧 GGUF 模型推荐清单及白名单 | `GET /api/v1/models/catalog` | 智宇 App 客户端 | 智宇后端 API / Model Hub | 包含模型架构、GGUF 量化版本、物理大小及 SHA256 签名 |
| **大模型管理** | 模型权重拉取/续传 | 后台静默下载 GGUF 模型权重物理文件 | `GET /gguf/{model_id}/{quant_file}.gguf` | 智宇 App 客户端 | CDN 存储节点 / 模型分发站 | 必须支持 HTTP `Range` 头 (`206 Partial Content`)，包含指纹校验 |
| **插件市场** | 拉取社区插件清单 | 获取云端已审核通过的 Obsidian 风格社区插件元数据 | `GET /api/v1/plugins/community-plugins.json` | 智宇 App 客户端 | 智宇 / GitHub CDN | 支持 `/community-plugins_zh-Hans.json` 本地化元数据分发 |
| **插件市场** | 下载插件 bundle 包 | 拉取并下载独立插件的 JavaScript 运行时包 | `GET /api/v1/plugins/{plugin_id}/bundle.zip` | 智宇 App 客户端 | 智宇 / GitHub CDN | `application/zip`；下载后在本地 JS 沙盒中安全解压解构 |
| **远程技能中心**| 获取云端技能列表 | 动态下发 Agent 技能 Prompt 模板及推理超参 | `GET /api/ai/skills/list` | 智宇 App 客户端 | 智宇后端 API 服务 | 故障/离线无网时自动优雅降级至本地内置 Agent 技能预设 |

---

## 二、 账号鉴权与个人资料模块 (Auth & User Profile)

### 2.1 获取当前登录用户 Profile
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/user/profile`
- **需要鉴权**：是 (`Bearer Token`)

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "userId": 10086,
    "username": "zhiyu_user_10086",
    "nick": "智宇研习者",
    "avatar": "https://cdn.zhiyu.app/avatars/10086.png",
    "email": "alex@example.com",
    "mobile": "13800008888",
    "gender": 1,
    "birthday": "1998-05-20"
  }
}
```

---

### 2.2 更新个人资料
- **HTTP 方法**：`PUT`
- **请求路径**：`/api/v1/user/profile`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求 Body 示例
```json
{
  "nick": "智宇领航员",
  "avatar": "https://cdn.zhiyu.app/avatars/new_avatar.png",
  "gender": 1,
  "birthday": "1998-05-20"
}
```

#### 字段说明
| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `nick` | String | 是 | 用户显示昵称 |
| `avatar` | String | 否 | 头像图片 URL 地址 |
| `gender` | Integer | 否 | 性别（`0`: 未知, `1`: 男, `2`: 女） |
| `birthday` | String | 否 | 生日日期字符串 (`YYYY-MM-DD`) |

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "profile updated successfully",
  "data": {
    "userId": 10086,
    "username": "zhiyu_user_10086",
    "nick": "智宇领航员",
    "avatar": "https://cdn.zhiyu.app/avatars/new_avatar.png",
    "email": "alex@example.com",
    "mobile": "13800008888",
    "gender": 1,
    "birthday": "1998-05-20"
  }
}
```

---

### 2.3 上传用户头像
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/user/profile/avatar`
- **Content-Type**：`multipart/form-data`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求表单参数
| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `file` | Binary File | 是 | 头像图片文件（支持 PNG / JPEG，最大 5MB） |

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "avatar uploaded successfully",
  "data": "https://cdn.zhiyu.app/avatars/20260723_avatar_10086.png"
}
```

---

### 2.4 账号登录与注册 (密码/验证码)
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/auth/login`
- **需要鉴权**：否

#### 请求 Body 示例（密码登录）
```json
{
  "grantType": "password",
  "username": "13800008888",
  "password": "Password123!"
}
```

#### 请求 Body 示例（短信验证码登录/注册）
```json
{
  "grantType": "sms",
  "phone": "13800008888",
  "code": "888888"
}
```

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "login success",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "rt_9876543210abcdef",
    "expiresIn": 2592000,
    "tokenType": "Bearer",
    "isNewUser": false,
    "totpRequired": false
  }
}
```

---

### 2.5 发送短信验证码
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/auth/sms/send`
- **需要鉴权**：否

#### 请求 Body 示例
```json
{
  "phone": "13800008888",
  "scene": "login"
}
```
*`scene` 场景支持：`login` (登录/注册), `reset_password` (重置密码)*

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "verification code sent",
  "data": null
}
```

---

### 2.6 第三方 OAuth / 免密登录
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/auth/oauth/{provider}`
  - 可选 `{provider}`：`apple` / `wechat` / `google` / `github` / `carrier`

#### 请求 Body 示例 (Apple 登录)
```json
{
  "code": "auth_code_from_apple",
  "state": "random_nonce_state",
  "idToken": "identity_token_string"
}
```

#### 响应示例 (`200 OK`)
同 2.4 返回 Token 凭证结构。

---

### 2.7 刷新 Token
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/auth/refresh`
- **需要鉴权**：否

#### 请求 Body 示例
```json
{
  "refreshToken": "rt_9876543210abcdef"
}
```

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "token refreshed",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.new...",
    "refreshToken": "rt_new_refresh_token",
    "expiresIn": 2592000
  }
}
```

---

### 2.8 退出登录 (Logout)
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/auth/logout`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求 Body 示例
```json
{
  "refreshToken": "rt_9876543210abcdef"
}
```

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "logged out successfully",
  "data": null
}
```

---

## 三、 订阅与套餐模块 (Subscriptions & Pricing)

### 3.1 获取可选订阅套餐列表
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/subscriptions/plans`
- **需要鉴权**：否

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "planKey": "free",
      "name": "基础版 (Lite)",
      "priceMonth": 0,
      "priceYear": 0,
      "maxVaults": 3,
      "maxPages": 1000,
      "maxPlugins": 5,
      "features": ["local_fts_search", "basic_note_editing"]
    },
    {
      "planKey": "pro",
      "name": "专业版 (Pro)",
      "priceMonth": 30,
      "priceYear": 288,
      "maxVaults": 100,
      "maxPages": 100000,
      "maxPlugins": 50,
      "features": ["local_fts_search", "rag_synthesis", "local_llm_acceleration", "unlimited_plugins"]
    }
  ]
}
```

---

### 3.2 获取当前用户的套餐信息
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/subscriptions/me`
- **需要鉴权**：是 (`Bearer Token`)

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "planKey": "pro",
    "status": "active",
    "expireAt": "2027-07-01T00:00:00Z",
    "quotasJson": "{\"max_vaults\": 100, \"max_pages\": 100000, \"max_plugins\": 50}",
    "featuresJson": "[\"local_fts_search\", \"rag_synthesis\", \"local_llm_acceleration\", \"unlimited_plugins\"]"
  }
}
```

---

### 3.3 验证 Apple 内购收据并激活订阅
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/subscriptions/apple/verify`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求 Body 示例
```json
{
  "productId": "com.zhiyu.app.pro.monthly",
  "receiptData": "MIITwAYJKoZIhvcNAQcCoIITsTCC...",
  "orderNo": "ORD_20260723_001"
}
```

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "purchase verified and pro activated",
  "data": {
    "orderNo": "ORD_20260723_001",
    "status": "completed",
    "planKey": "pro"
  }
}
```

---

## 四、 应用反馈与改进模块 (Feedback & AI Evaluation)

### 4.1 发送通用反馈改进
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/feedback/submit`
- **需要鉴权**：否 (推荐登录后提交)

#### 请求 Body 示例
```json
{
  "title": "希望能增加图形化的卡片盒展示",
  "category": "feature",
  "rating": 5,
  "content": "使用双链笔记时，图形化渲染可以帮助更好地梳理卡片盒概念逻辑。",
  "appVersion": "1.2.0",
  "osVersion": "macOS 15.1",
  "deviceModel": "MacBookPro18,1"
}
```

#### 字段说明
| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `title` | String | 是 | 反馈标题 |
| `category` | String | 是 | 分类 (`bug`: 缺陷, `feature`: 功能建议, `content`: 内容反馈, `other`: 其他) |
| `rating` | Integer | 是 | 满意度评分 (1 ~ 5 星) |
| `content` | String | 是 | 反馈正文描述 |
| `appVersion` | String | 否 | 应用客户端版本号 |
| `osVersion` | String | 否 | 操作系统版本 |
| `deviceModel` | String | 否 | 设备型号 |

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "feedback submitted",
  "data": {
    "id": "fb_20260723_999",
    "status": "synced",
    "createdAt": "2026-07-23T12:40:00Z"
  }
}
```

---

### 4.2 发送 AI 对话 / RAG 结果反馈
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/ai/chat/feedback`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求 Body 示例
```json
{
  "conversationId": "conv_888888",
  "messageId": "msg_777777",
  "evaluationId": 5001,
  "userRating": 2,
  "feedbackTags": ["accurate_citation", "deep_synthesis"],
  "comment": "RAG 引用的第二篇 Markdown 笔记非常契合回答语义。"
}
```

#### 字段说明
| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `conversationId` | String | 否 | 会话 ID |
| `messageId` | String | 否 | 消息 ID |
| `evaluationId` | Long | 否 | RAG 评估条目物理 ID |
| `userRating` | Integer | 是 | 评价类型：`2` (点赞 Thumbs Up), `1` (点踩 Thumbs Down) |
| `feedbackTags` | Array[String]| 否 | 评估标签集合 |
| `comment` | String | 否 | 详细评语 |

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "ai feedback recorded",
  "data": {
    "evaluationId": 5001,
    "userRating": 2,
    "updatedAt": "2026-07-23T12:41:00Z"
  }
}
```

---

### 4.3 发送 RAG 质量评估报告 (RAG Evaluation Benchmark Report)
- **HTTP 方法**：`POST`
- **请求路径**：`/api/v1/ai/rag/evaluation`
- **需要鉴权**：是 (`Bearer Token`)

#### 请求 Body 示例
```json
{
  "query": "Karpathy LLM Wiki 方法论的核心步骤是什么？",
  "answer": "核心步骤包含：1. 语义分块；2. 混合 FTS5+向量存储；3. AI 合成实验室（深度引用）。",
  "evaluatorModel": "gpt-4o-mini",
  "scores": {
    "faithfulnessScore": 0.95,
    "relevanceScore": 0.92,
    "contextPrecision": 0.88,
    "hallucinationRate": 0.03,
    "citationAccuracy": 0.96,
    "answerCorrectness": 0.94,
    "contextSufficiency": 0.90
  },
  "userRating": 2
}
```

#### 字段说明
| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `query` | String | 是 | 用户原始提问 Prompt |
| `answer` | String | 是 | RAG 检索并生成的回答正文 |
| `evaluatorModel` | String | 是 | 评估执行器模型标识（如 `LLM-as-a-Judge` 模型名称） |
| `scores.faithfulnessScore` | Double | 是 | 忠实度得分 `0.0 ~ 1.0` (AI 生成内容与检索上下文的吻合度) |
| `scores.relevanceScore` | Double | 是 | 答案相关度得分 `0.0 ~ 1.0` |
| `scores.contextPrecision` | Double | 是 | 检索上下文精准度 `0.0 ~ 1.0` |
| `scores.hallucinationRate` | Double | 是 | 幻觉率 `0.0 ~ 1.0` (无上下文支撑内容的占比，越低越好) |
| `scores.citationAccuracy` | Double | 是 | 引用准确度 `0.0 ~ 1.0` (角标引用对应原文的精准度) |
| `scores.answerCorrectness` | Double | 是 | 事实正确性得分 `0.0 ~ 1.0` |
| `scores.contextSufficiency` | Double | 是 | 检索上下文充分性 `0.0 ~ 1.0` (检索内容是否足以支持推演) |
| `userRating` | Integer | 否 | 用户满意度 (1: 差评, 2: 好评) |

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "rag evaluation report uploaded",
  "data": {
    "evaluationId": 5002,
    "createdAt": "2026-07-23T12:47:00Z"
  }
}
```

---

## 五、 本地大模型拉取与分发模块 (Local LLM Manager)

### 5.1 获取推荐云端大模型目录
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/models/catalog`
- **需要鉴权**：否

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "modelId": "qwen2.5-7b-instruct",
      "name": "Qwen2.5 7B Instruct",
      "architecture": "qwen2",
      "quantization": "Q4_K_M",
      "fileSizeBytes": 4680000000,
      "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "downloadUrl": "https://models.zhiyu.app/gguf/qwen2.5-7b-instruct-q4_k_m.gguf"
    },
    {
      "modelId": "llama3.2-3b-instruct",
      "name": "Llama 3.2 3B Instruct",
      "architecture": "llama",
      "quantization": "Q5_K_M",
      "fileSizeBytes": 2420000000,
      "sha256": "47d27e7f9a23a35b1c55209796e944ef0a324976c7014167e411b0e0081d69d4",
      "downloadUrl": "https://models.zhiyu.app/gguf/llama3.2-3b-instruct-q5_k_m.gguf"
    }
  ]
}
```

---

### 5.2 大模型权重断点续传/分块拉取
- **HTTP 方法**：`GET`
- **请求路径**：`/gguf/{model_id}/{quant_file}.gguf`
- **支持 Header**：`Range: bytes=start-end` (支持断点续传 HTTP `206 Partial Content`)
- **响应格式**：`application/octet-stream`

#### 断点续传 HTTP Headers 示例
```http
GET /gguf/qwen2.5-7b-instruct-q4_k_m.gguf HTTP/1.1
Host: models.zhiyu.app
Range: bytes=10485760-
```

#### HTTP 响应状态 (`206 Partial Content`)
```http
HTTP/1.1 206 Partial Content
Content-Range: bytes 10485760-4679999999/4680000000
Content-Length: 4669514240
Content-Type: application/octet-stream
```

---

## 六、 插件市场与分发模块 (Plugin Market)

### 6.1 拉取社区插件元数据列表
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/plugins/community-plugins.json` (或多语言分支 `/community-plugins_zh-Hans.json`)
- **需要鉴权**：否

#### 响应示例 (`200 OK`)
```json
[
  {
    "id": "toc-generator",
    "name": "TOC Table of Contents Generator",
    "author": "ZhiYu Open Source Community",
    "description": "Automatically generates dynamic interactive table of contents for long Markdown notes.",
    "version": "1.0.2",
    "icon": "list.bullet.rectangle.portrait",
    "category": "efficiency",
    "repo": "https://github.com/zhiyu-plugins/toc-generator",
    "names": {
      "zh": "自动目录生成器",
      "en": "TOC Table of Contents Generator"
    },
    "descriptions": {
      "zh": "自动为长篇 Markdown 笔记提取多级标题并生成交互式目录列表。",
      "en": "Automatically generates dynamic interactive table of contents for long Markdown notes."
    }
  },
  {
    "id": "smart-cleaner",
    "name": "Smart Markdown Formatting Cleaner",
    "author": "ZhiYu Labs",
    "description": "Cleans up formatting irregularities and orphan links.",
    "version": "1.1.0",
    "icon": "wand.and.stars",
    "category": "utility",
    "repo": "https://github.com/zhiyu-plugins/smart-cleaner",
    "names": {
      "zh": "智能格式清理器",
      "en": "Smart Markdown Formatting Cleaner"
    },
    "descriptions": {
      "zh": "一键修复 Markdown 中的空行过多、未对齐列表及孤儿链接。",
      "en": "Cleans up formatting irregularities and orphan links."
    }
  }
]
```

---

### 6.2 下载插件完整 bundle
- **HTTP 方法**：`GET`
- **请求路径**：`/api/v1/plugins/{plugin_id}/bundle.zip`
- **需要鉴权**：否
- **响应 Content-Type**：`application/zip`

---

## 七、 远程配置与 AI 技能中心 (Remote Config & Skills Hub)

### 7.1 获取云端技能配置列表
- **HTTP 方法**：`GET`
- **请求路径**：`/api/ai/skills/list`
- **需要鉴权**：否

#### 响应示例 (`200 OK`)
```json
{
  "code": 200,
  "message": "success",
  "data": [
    {
      "skillId": "deep_rag_synthesis",
      "name": "深度 RAG 知识合成",
      "version": "2.1.0",
      "systemPrompt": "You are a professional knowledge synthesizer built on Karpathy's LLM Wiki architecture...",
      "enabled": true
    },
    {
      "skillId": "markdown_lint_cleaner",
      "name": "Markdown 自动诊断与修复",
      "version": "1.0.5",
      "systemPrompt": "Analyze the input document for style violations and return structured diff...",
      "enabled": true
    }
  ]
}
```

---

## 八、 版本的演进与文档维护规则

1. **版本控制**：所有受保护的业务 API 统一下发在 `/api/v1/` 命名空间下。若发生破坏性变更 (Breaking Changes)，将被升阶至 `/api/v2/`。
2. **多语言错误消息**：响应中的 `message` 建议根据请求头的 `Accept-Language` 下发本地化的错误短语。
3. **频率限制 Header**：超出频次时服务器将包含以下标头：
   - `X-RateLimit-Limit`: 当前周期允许最大请求数
   - `X-RateLimit-Remaining`: 剩余可用额度
   - `X-RateLimit-Reset`: 额度重置 UTC 时间戳
