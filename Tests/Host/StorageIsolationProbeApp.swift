//
//  StorageIsolationProbeApp.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试宿主
//  核心职责：向 UI 自动化只读呈现实际存储边界，验证进程重启后的目录隔离。
//
import SwiftUI

/// 此场景仅存在于独立测试应用，正式 target 不包含诊断入口。
struct StorageIsolationProbeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text(Bundle.main.bundleIdentifier ?? ProbeValue.missing)
                    .accessibilityIdentifier(ProbeField.bundle)
                Text(ApplicationStorageLocation.applicationSupport.path)
                    .accessibilityIdentifier(ProbeField.root)
                Text(KeychainService.shared is UITestMemoryKeychainService ? ProbeValue.memory : ProbeValue.persistent)
                    .accessibilityIdentifier(ProbeField.keychain)
                Text(DatabaseManager.shared.usesTransientStorage ? ProbeValue.memory : ProbeValue.persistent)
                    .accessibilityIdentifier(ProbeField.mode)
                Text(DatabaseManager.shared.dbURL?.path ?? ProbeValue.missing)
                    .accessibilityIdentifier(ProbeField.database)
                Text(DatabaseManager.shared.globalDBURL?.path ?? ProbeValue.missing)
                    .accessibilityIdentifier(ProbeField.globalDatabase)
            }
        }
    }
}

private enum ProbeField {
    static let bundle = "isolation.bundle"
    static let root = "isolation.root"
    static let keychain = "isolation.keychain"
    static let mode = "isolation.mode"
    static let database = "isolation.database"
    static let globalDatabase = "isolation.globalDatabase"
}

private enum ProbeValue {
    static let missing = "none"
    static let memory = "memory"
    static let persistent = "persistent"
}
