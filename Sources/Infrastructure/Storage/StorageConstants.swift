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
        static let `true` = "true"
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
    enum SQLiteExtension {
        static let sqlite = "sqlite"
        static let sqlite3 = "sqlite3"
        static let walSuffix = "-wal"
        static let shmSuffix = "-shm"
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
    enum LogConcat {
        static let separator = ", "
        static let arrow = " + "
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

    enum MarkdownSyntax {
        static let hashSpace = "# "
        static let hashHashSpace = "## "
        static let asteriskSpace = "* "
        static let dashSpace = "- "
        static let blockquoteSpace = "> "
        static let bold = "**"
        static let wikilinkOpen = "[["
        static let wikilinkClose = "]]"
        static let tableDelimiter = "|-"
        static let tableSeparator = "|:"
    }
}
