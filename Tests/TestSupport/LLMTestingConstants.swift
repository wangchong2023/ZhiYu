//
//  LLMTestingConstants.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：集中保存测试响应参数，禁止进入生产模块。
//

extension LLMConstants {
    // MARK: - UI 自动化测试 Mock 参数 (UITesting Mock Parameters)

    /// UI 自动化测试模式下 Mock 响应参数常量集
    /// 集中管理 `--uitesting` 自愈分支的延迟、Mock 文本与流式 chunks
    public enum UITesting {
        /// UI 自动化测试启动参数标记
        public static let launchArg: String = "--uitesting"
        /// 纳秒与秒的换算系数
        public static let nanosecondsPerSecond: Double = 1_000_000_000
        /// 非流式 Mock 响应初始延迟（秒）
        public static let mockNonStreamDelaySeconds: Double = 0.5
        /// 流式 Mock 响应初始延迟（秒），模拟 RAG 检索/思考状态
        public static let mockStreamInitialDelaySeconds: Double = 1.5
        /// 流式 Mock 字间吐字延迟（秒）
        public static let mockStreamChunkDelaySeconds: Double = 0.15

        /// 非流式 Mock 大模型回复内容（纯 ASCII，避免 L10n 红线）
        public static let mockNonStreamReply: String = "Mock non-stream LLM reply for UI testing."
        /// Mock RAG 回复内容（纯 ASCII，避免 L10n 红线）
        public static let mockRAGReply: String = "Mock non-stream RAG reply for UI testing."

        /// 流式 Mock 打字机 chunks 数组（纯 ASCII，避免 L10n 红线）
        public static let mockStreamChunks: [String] = [
            "Mock", " stream", " LLM", " reply", " for", " UI", " testing.",
            " Supports", " RAG", " deep", " citation", " retrieval", " auto-heal."
        ]
    }

}
