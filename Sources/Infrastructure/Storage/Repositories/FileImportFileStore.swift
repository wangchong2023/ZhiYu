//
//  FileImportFileStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：导入原始文件持久化实现

import Foundation
import UFPCore
import Dependencies

final class FileImportFileStore: ImportFileStore, @unchecked Sendable {

    init() {
        // 无需预先创建 recordsDir，全部采用动态延迟计算
    }

    /// Factory 风格：属性类型标注为可选（T?），@Dependency 自动使用 resolveOptional
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    private func getCategoryDirName(for category: ImportCategory) -> String {
        switch category {
        case .file: return "document"
        case .voice: return "audio"
        case .ocr: return "ocr"
        case .link: return "web"
        case .clipboard: return "clipboard"
        case .manual: return "manual"
        }
    }

    private func getRecordsDir(for category: ImportCategory) -> URL {
        let fm = FileManager.default
        let categoryDirName = getCategoryDirName(for: category)
        
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        
        // KeyStore reads require @MainActor due to KeyStoreProtocol isolation;
        // use assumeIsolated in @unchecked Sendable class where runtime context is known-safe
        let vaultIDString = runOnMainSync({ keyStore?.string(forKey: AppConstants.Keys.Storage.vaultsSelectedID) })
        let englishName = runOnMainSync({ keyStore?.string(forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName) })
        
        if let vaultIDString, let englishName, !vaultIDString.isEmpty, !englishName.isEmpty {
            
            // 物理落盘到 Vaults/{Vault_UUID}/raw/{笔记本英文名}/{Category}/
            let vaultsDir = appSupport
                .appendingPathComponent(AppConstants.Storage.vaultsDirectoryName)
                .appendingPathComponent(vaultIDString)
                .appendingPathComponent("raw")
                .appendingPathComponent(englishName)
                .appendingPathComponent(categoryDirName)
            
            try? fm.createDirectory(at: vaultsDir, withIntermediateDirectories: true)
            return vaultsDir
        } else {
            // fallback 兜底路径: Documents/import_records/
            let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
            let fallbackDir = docDir.appendingPathComponent("import_records", isDirectory: true)
            try? fm.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
            return fallbackDir
        }
    }

    func saveContent(_ content: String, category: ImportCategory, ext: String = "md") -> String? {
        guard let data = content.data(using: .utf8) else { return nil }
        return saveData(data, category: category, ext: ext)
    }

    func saveData(_ data: Data, category: ImportCategory, ext: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let ts = formatter.string(from: Date())
        let fileName = "\(category.rawValue)_\(ts).\(ext)"
        let recordsDir = getRecordsDir(for: category)
        let fileURL = recordsDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL.path
        } catch {
            Logger.shared.error("[ImportFileStore] 保存文件失败: \(error)", error: error)
            return nil
        }
    }

    /// 将指定路径的外部物理文件复制到沙盒内部
    /// - Parameters:
    ///   - url: 外部文件 URL
    ///   - category: 导入资源类别
    /// - Returns: 拷贝后的沙盒内绝对路径，失败时返回 nil
    func copyFile(at url: URL, category: ImportCategory) -> String? {
        let fileManager = FileManager.default
        
        // 针对可能需要安全访问权限的外部 URL 获取权限
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let ext = url.pathExtension
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let ts = formatter.string(from: Date())
        
        // 构造带时间戳的新物理文件名以防重名冲突
        let newFileName = "\(nameWithoutExt)_\(ts).\(ext)"
        let recordsDir = getRecordsDir(for: category)
        let destinationURL = recordsDir.appendingPathComponent(newFileName)
        
        do {
            // 如若目标物理文件此前已存在，先执行删除
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // 执行物理拷贝
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL.path
        } catch {
            Logger.shared.error("[ImportFileStore] 拷贝外部文件失败: \(error)", error: error)
            return nil
        }
    }
}
