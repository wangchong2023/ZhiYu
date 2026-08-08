//
//  StorageConstants.swift
//  ZhiYu
//
//  系统层级：[L1] 基础设施层
//  核心职责：Storage 模块业务常量集（来源类型/同步状态/日志模块名/SQL 关键字/CloudKit/Bundle 资源等）
//

import UFPCore

/// Storage 模块业务常量集
enum StorageConstants {

    // MARK: - 知识页来源类型 (Source Type)
    enum SourceType {
        static let markdown = "markdown"
        static let md = "md"
        static let ocr = "ocr"
        static let link = "link"
        static let voice = "voice"
        static let pdf = "pdf"
        static let file = "file"
        static let clipboard = "clipboard"
        static let manual = "manual"
    }

    // MARK: - 同步状态 (Sync Status)
    enum SyncStatus {
        static let active = "active"
        static let pending = "pending"
        static let local = "local"
        static let llmAuto = "llm-auto"
        static let emptyArray = "[]"
    }

    // MARK: - 优先级 (Priority)
    enum Priority {
        static let medium = "medium"
    }

    // MARK: - 操作状态 (Operation Status)
    enum OperationStatus {
        static let success = "success"
        static let done = "done"
        /// 引用 SystemConstants.BooleanLiteral.true，避免重复定义
        static let `true`: String = SystemConstants.BooleanLiteral.true
    }

    // MARK: - 日志模块名 (Log Module)
    enum LogModule {
        static let maintenance = "Maintenance"
        static let backupService = "BackupService"
        static let core = "Core"
    }

    // MARK: - 日志目标名 (Log Target)
    enum LogTarget {
        static let dataCoordinator = "DataCoordinator"
        static let backupService = "BackupService"
        static let vaultStorageService = "VaultStorageService"
    }

    // MARK: - 日志详情模板 (Log Details)
    enum LogDetails {
        static let initialNotebookVaultCreated = "InitialNotebook_VaultCreated"
        static let initialNotebookFailed = "InitialNotebook_Failed"
        static let initialNotebookPageCountRefreshed = "InitialNotebook_PageCountRefreshed"
        static let seededDefaultContent = "Seeded_default_content"
        static let seededResearchContent = "Seeded_research_content"
        static let seededFallbackContent = "Seeded_fallback_content"
        static let seedFailedPrefix = "Seed_Failed: "
        static let dataCoordinatorStart = "DataCoordinator_Start"
        static let dataCoordinatorEnd = "DataCoordinator_End"
        static let appBackupSuccess1 = "AppBackup_Success1"
        static let appBackupSuccess2 = "AppBackup_Success2"
        static let vaultFailed1 = "Vault_Failed1"
        static let errorPlaceholder = "%@"
    }

    // MARK: - 环境变量与启动参数 (Launch Environment & Arguments)
    enum LaunchEnvironment {
        /// UI 自动化测试环境变量 Key
        static let uitestingEnvKey = "UITesting"
        /// UI 自动化测试启动参数
        static let uitestingLaunchArg = "--uitesting"
    }

    // MARK: - 测试名称匹配标记 (Test Name Markers)
    /// 测试环境下笔记本名称子串匹配标记
    enum TestName {
        /// 默认知识管理笔记本名称标记
        static let vaultMarker: String = "Vault"
        /// 项目调研笔记本名称标记
        static let researchMarker: String = "Research"
    }

    // MARK: - 错误域 (Error Domain)
    enum ErrorDomain {
        static let databaseManager = "DatabaseManager"
        static let cloudKitSyncProvider = "CloudKitSyncProvider"
    }

    // MARK: - SQL 关键字 (SQL Keywords)
    enum SQL {
        static let insertOr = "INSERT OR"
        static let rank = "rank"
    }

    // MARK: - SQLite 文件扩展名 (SQLite File Extension)
    /// 引用 SystemConstants.FileExtension，避免重复定义
    enum SQLiteExtension {
        static let sqlite: String = SystemConstants.FileExtension.sqlite
        static let sqlite3: String = SystemConstants.FileExtension.sqlite3
        static let walSuffix: String = SystemConstants.FileExtension.walSuffix
        static let shmSuffix: String = SystemConstants.FileExtension.shmSuffix
    }

    // MARK: - CloudKit (CloudKit Zone)
    enum CloudKit {
        static let appZone = "AppZone"
    }

    // MARK: - JSON 字典 Key (JSON Dictionary Key)
    enum JSONKey {
        static let url = "url"
        static let vaultID = "vaultID"
    }

    // MARK: - 日志拼接符 (Log Concatenation)
    /// 引用 SystemConstants.Separator，避免重复定义
    enum LogConcat {
        static let separator: String = SystemConstants.Separator.commaSpace
        static let arrow: String = SystemConstants.Separator.arrow
    }

    // MARK: - Bundle 资源名 (Bundle Resource)
    enum BundleResource {
        static let ocrFolderScan = "ocr_folder_scan.png"
        static let ocrStoreManual = "ocr_store_manual.png"
        static let voiceNoteProcurement = "voice_note_procurement.mp3"
    }

    // MARK: - 备份文件 (Backup File)
    enum Backup {
        static let prefix = "backup_"
    }

    // MARK: - 数据库写入器重试 (Database Writer Retry)
    enum WriterRetry {
        /// 最大重试次数（等待 notebook 切换完成）
        static let maxAttempts: Int = 20
        /// 单次重试间隔（纳秒，50ms）
        static let intervalNanoseconds: UInt64 = 50_000_000
    }

    /// 引用 SystemConstants.MarkdownSyntax，避免重复定义
    enum MarkdownSyntax {
        /// 引用 SystemConstants.MarkdownSyntax.h1Prefix
        static let hashSpace: String = SystemConstants.MarkdownSyntax.h1Prefix
        /// 引用 SystemConstants.MarkdownSyntax.h2Prefix
        static let hashHashSpace: String = SystemConstants.MarkdownSyntax.h2Prefix
        /// 引用 SystemConstants.MarkdownSyntax.bulletAsterisk
        static let asteriskSpace: String = SystemConstants.MarkdownSyntax.bulletAsterisk
        /// 引用 SystemConstants.MarkdownSyntax.bulletDash
        static let dashSpace: String = SystemConstants.MarkdownSyntax.bulletDash
        static let blockquoteSpace = "> "
        /// 引用 SystemConstants.MarkdownSyntax.bold
        static let bold: String = SystemConstants.MarkdownSyntax.bold
        static let wikilinkOpen = "[["
        static let wikilinkClose = "]]"
        static let tableDelimiter = "|-"
        static let tableSeparator = "|:"
        /// 引用 SystemConstants.MarkdownSyntax.tableRowSeparator
        static let tableRowSeparator: String = SystemConstants.MarkdownSyntax.tableRowSeparator
    }
}
