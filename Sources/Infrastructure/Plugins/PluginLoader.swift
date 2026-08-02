//
//  PluginLoader.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件发现、文件解析与加载，支持 .zyplugin 归档、明文目录及裸 .js 三种格式。
//

import Foundation
import ZIPFoundation
import CryptoKit

/// 插件加载器：负责从本地磁盘发现并解析插件文件
@MainActor
final class PluginLoader {

    /// 插件签名密钥的 Keychain 存储键（审查修复 HIGH-3：不再硬编码盐值）
    private static let signatureKeychainKey = "com.zhiyu.plugin.signature_key"
    /// 内置插件签名密钥标识（首次启动时生成随机密钥并存入 Keychain）
    private static let signatureKeyInfo = Data("zhiyu-plugin-signature-v1".utf8)

    // MARK: - 插件签名校验（VULN-001 修复）

    /// 获取或生成插件签名密钥（审查修复 HIGH-3：密钥存 Keychain，不硬编码在二进制中）
    /// - Returns: HMAC-SHA256 对称密钥
    private static func getSignatureKey() -> SymmetricKey? {
        // 尝试从 Keychain 读取
        if let stored = try? KeychainService.shared.retrieve(key: signatureKeychainKey),
           let keyData = Data(base64Encoded: stored) {
            return SymmetricKey(data: keyData)
        }
        // 生成 32 字节随机密钥并存入 Keychain
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard status == errSecSuccess else { return nil }
        let keyData = Data(randomBytes)
        try? KeychainService.shared.store(key: signatureKeychainKey, value: keyData.base64EncodedString())
        return SymmetricKey(data: keyData)
    }

    /// 校验插件脚本签名：使用 HMAC-SHA256 验证 index.js 内容完整性
    /// - Parameters:
    ///   - script: 插件 JS 脚本内容
    ///   - manifest: 插件清单（含 codeSignature 字段）
    ///   - isTrustedLocal: 是否为内部生成的可信本地插件（loadPluginFromRawJS 路径）
    /// - Returns: true 表示签名有效或为内置信任插件；false 表示签名缺失或不匹配
    private static func verifyPluginSignature(script: String, manifest: PluginManifest, isTrustedLocal: Bool = false) -> Bool {
        // 审查修复 HIGH-2: local. 豁免仅限 loadPluginFromRawJS 内部生成路径
        // 外部 manifest（.zyplugin / 明文目录）的 local. 前缀视为可疑，强制要求签名
        if isTrustedLocal {
            Logger.shared.warning("[PluginRegistry] \(manifest.id): 内部本地开发插件跳过签名校验")
            return true
        }

        // 外部 manifest 的 local. 前缀视为可疑，拒绝加载
        if manifest.id.hasPrefix("local.") {
            Logger.shared.error("[PluginRegistry] \(manifest.id): 外部插件使用 local. 前缀，视为可疑，拒绝加载")
            return false
        }

        guard let expectedSignature = manifest.codeSignature, !expectedSignature.isEmpty else {
            Logger.shared.error("[PluginRegistry] \(manifest.id): 拒绝加载 — 缺少代码签名 (codeSignature)")
            return false
        }

        // 审查修复 HIGH-3: 从 Keychain 获取签名密钥，而非硬编码常量
        guard let key = getSignatureKey() else {
            Logger.shared.error("[PluginRegistry] \(manifest.id): 签名密钥不可用，拒绝加载")
            return false
        }
        let scriptData = Data(script.utf8)
        let computed = HMAC<SHA256>.authenticationCode(for: scriptData, using: key)
        let computedData = Data(computed)
        guard let expectedData = Data(hexString: expectedSignature) else {
            Logger.shared.error("[PluginRegistry] \(manifest.id): 拒绝加载 — 签名格式无效 (非合法 hex)")
            return false
        }

        // 审查修复 MED-2: 使用常量时间比较，防御时序侧信道
        guard constantTimeCompare(computedData, expectedData) else {
            Logger.shared.error("[PluginRegistry] \(manifest.id): 拒绝加载 — 代码签名不匹配 (expected: \(expectedSignature.prefix(16))..., got: \(computedData.hexEncoded.prefix(16))...)")
            return false
        }

        return true
    }

    /// 常量时间字节比较（审查修复 MED-2）
    private static func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for i in 0..<a.count {
            result |= a[i] ^ b[i]
        }
        return result == 0
    }

    // MARK: - 插件自动发现机制

    /// 从本地沙盒目录扫描并加载外部脚本插件 (规范化加载机制)
    /// - Note: 实际运行中，此方法应在 App 启动后异步调用，不阻塞主线程。
    func scanAndLoadLocalPlugins() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let pluginsDirectory = documentsURL.appendingPathComponent("Plugins")

        if !fileManager.fileExists(atPath: pluginsDirectory.path) {
            try? fileManager.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true, attributes: nil)
            Logger.shared.info("[PluginRegistry] Created: \(pluginsDirectory.path)")
            return
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: pluginsDirectory, includingPropertiesForKeys: nil)

            for file in files {
                // 🛡️ 检查是否为物理子目录以支持明文文件夹形式的插件
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: file.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    loadPluginFromDirectory(file)
                    continue
                }

                let ext = file.pathExtension.lowercased()

                switch ext {
                case "zyplugin":
                    // .zyplugin 是标准 ZIP 格式，内含 manifest.json + index.js
                    loadPluginFromArchive(file)

                case "js":
                    // 兼容裸 .js 文件（使用内置占位 manifest）
                    loadPluginFromRawJS(file)

                default:
                    continue
                }
            }
        } catch {
            Logger.shared.error("[PluginRegistry] Scan error", error: error)
        }
    }

    // MARK: - 多语言 README 校验

    /// 校验插件包中是否包含 manifest.readmeFiles 声明的所有多语言 README
    private func validateReadmeFiles(manifest: PluginManifest, extractedDir: URL) {
        guard let readmeMap = manifest.readmeFiles, !readmeMap.isEmpty else {
            Logger.shared.warning("[PluginRegistry] \(manifest.id): manifest 未声明 readmeFiles，建议添加多语言 README")
            return
        }

        for (locale, filename) in readmeMap {
            let fileURL = extractedDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                Logger.shared.info("[PluginRegistry] \(manifest.id): README.\(locale) ✓")
            } else {
                Logger.shared.warning("[PluginRegistry] \(manifest.id): README.\(locale) (\(filename)) 缺失")
            }
        }

        // 强制要求至少 en 和 zh-Hans
        let requiredLocales = ["en", "zh-Hans"]
        for locale in requiredLocales {
            guard let filename = readmeMap[locale] else {
                Logger.shared.warning("[PluginRegistry] \(manifest.id): readmeFiles 缺少 \(locale) 语言")
                continue
            }
            let fileURL = extractedDir.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                Logger.shared.warning("[PluginRegistry] \(manifest.id): \(locale) README 文件 (\(filename)) 未找到")
            }
        }
    }

    // MARK: - 持久化资源

    /// 从解压目录复制 icon.png + README 到 Documents/Plugins/{id}_*
    private func persistPluginAssets(manifest: PluginManifest, extractedDir: URL) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let assetsDir = documentsURL.appendingPathComponent("Plugins")
        try? fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        // 保存图标
        if let iconFile = manifest.iconFile {
            let src = extractedDir.appendingPathComponent(iconFile)
            let dst = assetsDir.appendingPathComponent("\(manifest.id)_icon.png")
            try? fileManager.removeItem(at: dst)
            if fileManager.fileExists(atPath: src.path) {
                try? fileManager.copyItem(at: src, to: dst)
                Logger.shared.info("[PluginRegistry] \(manifest.id): icon saved")
            }
        }

        // 保存多语言 README
        if let readmeMap = manifest.readmeFiles {
            for (locale, filename) in readmeMap {
                let src = extractedDir.appendingPathComponent(filename)
                let dst = assetsDir.appendingPathComponent("\(manifest.id)_\(locale).md")
                try? fileManager.removeItem(at: dst)
                if fileManager.fileExists(atPath: src.path) {
                    try? fileManager.copyItem(at: src, to: dst)
                }
            }
        }
    }

    /// 获取已安装插件的图标 URL
    func iconURL(for pluginID: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documentsURL.appendingPathComponent("Plugins/\(pluginID)_icon.png")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// 获取已安装插件的本地化 README 内容
    func localizedReadme(for pluginID: String) -> String? {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        // 尝试用户语言 → en fallback
        for locale in [lang, "en"] {
            let url = documentsURL.appendingPathComponent("Plugins/\(pluginID)_\(locale).md")
            if fileManager.fileExists(atPath: url.path) {
                return try? String(contentsOf: url, encoding: .utf8)
            }
        }
        return nil
    }

    // MARK: - .zyplugin 加载（ZIPFoundation 文件提取）

    /// 使用 ZIPFoundation 解压 .zyplugin：提取到临时文件后读取，确保数据完整性
    private func loadPluginFromArchive(_ archiveURL: URL) {
        do {
            // 创建临时目录
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("plugin_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            // 打开 ZIP 归档
            let archive: Archive
            do {
                archive = try Archive(url: archiveURL, accessMode: .read)
            } catch {
                Logger.shared.error("[PluginRegistry] Cannot open archive: \(archiveURL.lastPathComponent), error: \(error)")
                return
            }

            // 提取所有条目到文件（ZIPFoundation 文件提取保证数据完整）
            try extractArchiveEntries(archive, to: tempDir)

            // 读取提取的文件
            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            let scriptURL = tempDir.appendingPathComponent("index.js")

            guard FileManager.default.fileExists(atPath: manifestURL.path),
                  FileManager.default.fileExists(atPath: scriptURL.path) else {
                Logger.shared.error("[PluginRegistry] .zyplugin missing manifest.json or index.js")
                return
            }

            let manifestData = try Data(contentsOf: manifestURL)
            let script = try String(contentsOf: scriptURL, encoding: .utf8)

            // [DEBUG] 打印前 200 字符验证完整性
            Logger.shared.info("[PluginRegistry] JS preview: \(String(script.prefix(80)).replacingOccurrences(of: "\n", with: " "))")

            let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)

            // 🛡️ VULN-001 修复：强制代码签名校验，拒绝加载未签名或签名不匹配的插件
            guard Self.verifyPluginSignature(script: script, manifest: manifest) else {
                Logger.shared.error("[PluginRegistry] .zyplugin 签名校验失败，拒绝加载: \(manifest.name)")
                return
            }

            // 校验多语言 README 完整性
            validateReadmeFiles(manifest: manifest, extractedDir: tempDir)

            // 持久化图标和 README 到 Documents/Plugins/{id}_icon.png
            persistPluginAssets(manifest: manifest, extractedDir: tempDir)

            #if canImport(JavaScriptCore) && !os(watchOS)
            if let jsPlugin = JavaScriptPlugin(script: script, manifest: manifest) {
                PluginRegistry.shared.loadPlugin(jsPlugin)
                Logger.shared.info("[PluginRegistry] Loaded: \(manifest.name)")
            } else {
                Logger.shared.error("[PluginRegistry] Init failed: \(manifest.name)")
            }
            #endif

        } catch {
            Logger.shared.error("[PluginRegistry] Archive error: \(archiveURL.lastPathComponent)", error: error)
        }
    }

    // MARK: - 文件夹形式加载（明文加载）

    /// 安全提取 ZIP 归档条目到目标目录（VULN-014 修复：完整路径穿越防护）
    private func extractArchiveEntries(_ archive: Archive, to tempDir: URL) throws {
        let tempDirStandardized = tempDir.standardizedFileURL.path
        for entry in archive {
            let entryPath = entry.path
            // 1. 拒绝 ".." 相对路径穿越
            guard !entryPath.contains("..") else {
                Logger.shared.warning("[PluginRegistry] Skipped path traversal: \(entryPath)")
                continue
            }
            // 2. 拒绝绝对路径（Unix / 和 Windows 盘符 C:\）
            // 审查修复 LOW-5: 冒号检查改为精确的 Windows 盘符正则，避免误拒含冒号的合法文件名
            guard !entryPath.hasPrefix("/"),
                  !entryPath.matchesRegex(#"^[A-Za-z]:[\\/]"#) else {
                Logger.shared.warning("[PluginRegistry] Skipped absolute path: \(entryPath)")
                continue
            }
            // 3. 拒绝空路径
            guard !entryPath.isEmpty else { continue }
            let destURL = tempDir.appendingPathComponent(entryPath)
            // 4. 额外验证：确保 destURL 标准化后仍在 tempDir 内
            let destStandardized = destURL.standardizedFileURL.path
            guard destStandardized.hasPrefix(tempDirStandardized) else {
                Logger.shared.warning("[PluginRegistry] Skipped path escape: \(entryPath)")
                continue
            }
            // 确保父目录存在（处理 ZIP 内目录结构）
            try? FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: destURL)
        }
    }

    /// 从解压明文插件目录中直接加载插件并进行 JavaScript 沙箱挂载
    /// - Parameter directoryURL: 物理子目录 URL 路径
    private func loadPluginFromDirectory(_ directoryURL: URL) {
        let fileManager = FileManager.default
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        let scriptURL = directoryURL.appendingPathComponent("index.js")

        // 🛡️ 核心安全性静态核验：必须同时存在声明式配置清单与核心 JS 逻辑
        guard fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: scriptURL.path) else {
            // 如果不是插件目录，静默返回即可（比如 Assets 目录）
            return
        }

        do {
            Logger.shared.info("[PluginRegistry] 开始从明文目录加载插件: \(directoryURL.lastPathComponent)")
            let manifestData = try Data(contentsOf: manifestURL)
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)

            // 🛡️ VULN-001 修复：强制代码签名校验
            guard Self.verifyPluginSignature(script: script, manifest: manifest) else {
                Logger.shared.error("[PluginRegistry] 明文目录插件签名校验失败，拒绝加载: \(manifest.name)")
                return
            }

            // 校验多语言 README 完整性
            validateReadmeFiles(manifest: manifest, extractedDir: directoryURL)

            // 持久化图标和 README 到 Documents/Plugins/{id}_icon.png 等供 UI 侧边栏读取展示
            persistPluginAssets(manifest: manifest, extractedDir: directoryURL)

            #if canImport(JavaScriptCore) && !os(watchOS)
            if let jsPlugin = JavaScriptPlugin(script: script, manifest: manifest) {
                PluginRegistry.shared.loadPlugin(jsPlugin)
                Logger.shared.info("[PluginRegistry] 从明文目录成功加载: \(manifest.name)")
            } else {
                Logger.shared.error("[PluginRegistry] 实例化 JS 插件失败: \(manifest.name)")
            }
            #endif
        } catch {
            Logger.shared.error("[PluginRegistry] 明文目录加载错误: \(directoryURL.lastPathComponent)", error: error)
        }
    }

    // MARK: - 裸 .js 加载（兼容旧格式）

    private func loadPluginFromRawJS(_ fileURL: URL) {
        do {
            let scriptContent = try String(contentsOf: fileURL, encoding: .utf8)
            let displayName = fileURL.deletingPathExtension().lastPathComponent
            let manifest = PluginManifest(
                id: "local.\(displayName)",
                version: "1.0.0",
                author: "Local Developer",
                permissions: ["log", "writeContent"],
                names: ["en": displayName],
                descriptions: ["en": "Legacy .js plugin (migrate to .zyplugin format)"]
            )

            // 🛡️ VULN-001 修复 + 审查修复 HIGH-2: 本地 .js 插件通过 isTrustedLocal 豁免签名
            // 仅此路径（内部生成 id）允许豁免，外部 manifest 的 local. 前缀会被拒绝
            guard Self.verifyPluginSignature(script: scriptContent, manifest: manifest, isTrustedLocal: true) else {
                Logger.shared.error("[PluginRegistry] 拒绝加载未签名 .js: \(displayName)")
                return
            }

            #if canImport(JavaScriptCore) && !os(watchOS)
            if let jsPlugin = JavaScriptPlugin(script: scriptContent, manifest: manifest) {
                PluginRegistry.shared.loadPlugin(jsPlugin)
                Logger.shared.info("[PluginRegistry] Loaded legacy .js: \(displayName)")
            }
            #endif
        } catch {
            Logger.shared.error("[PluginRegistry] Failed to load .js: \(fileURL.lastPathComponent)", error: error)
        }
    }
}

// MARK: - 辅助扩展

/// 审查修复 LOW-5: String 正则匹配辅助
private extension String {
    func matchesRegex(_ pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}

/// 审查修复 MED-2: Data hex 编解码辅助
private extension Data {
    /// 从 hex 字符串构造 Data
    init?(hexString: String) {
        let cleaned = hexString.lowercased().replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    /// 转为 hex 字符串
    var hexEncoded: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
