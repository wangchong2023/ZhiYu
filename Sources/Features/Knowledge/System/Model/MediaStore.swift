//
//  MediaStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：数据模型与状态管理，定义数据结构与 @Observable 状态。
//
import Foundation
import CryptoKit

/// 媒体存储器
/// 专门物理托管特定笔记本（Vault）沙盒目录下的非文本型多媒体二进制资产。
public final class MediaStore: Sendable {
    /// 目标笔记本的根路径
    public let vaultURL: URL
    
    /// 附件存储相对子路径
    private let attachmentsDirectoryName = "Attachments"
    
    /// 获取物理存储目录的绝对路径 URL
    public var attachmentsDirectoryURL: URL {
        vaultURL.appendingPathComponent(attachmentsDirectoryName, isDirectory: true)
    }
    
    /// 初始化媒体存储器
    /// - Parameter vaultURL: 物理笔记本的沙盒根路径
    public init(vaultURL: URL) {
        self.vaultURL = vaultURL
        ensureAttachmentsDirectoryExists()
    }
    
    /// 确保附件物理存储目录已在沙盒中创建
    private func ensureAttachmentsDirectoryExists() {
        let path = attachmentsDirectoryURL
        if !FileManager.default.fileExists(atPath: path.path) {
            do {
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // 1. 静默创建失败时打印日志，不抛出异常以维持基础组件的高可用
                Logger.shared.error("[MediaStore] Failed to create media directory", error: error)
            }
        }
    }
    
    /// 将二进制附件物理保存到沙盒，并生成以 MD5 命名的唯一物理路径。
    ///
    /// - Parameters:
    ///   - data: 附件的原始二进制数据
    ///   - fileExtension: 文件扩展名（例如 "png"、"pdf"）
    /// - Returns: 保存成功后的相对路径或唯一文件名，可用于存储在数据库中
    /// - Throws: 物理写入失败时抛出错误
    public func saveMedia(data: Data, fileExtension: String) throws -> String {
        // 1. 计算二进制数据的 MD5 校验和作为唯一文件名
        let hash = Insecure.MD5.hash(data: data)
        let hexString = hash.map { String(format: "%02hhx", $0) }.joined()
        let fileName = "\(hexString).\(fileExtension.lowercased())"
        
        let destinationURL = attachmentsDirectoryURL.appendingPathComponent(fileName)
        
        // 2. 物理写入文件系统
        try data.write(to: destinationURL, options: .atomic)
        
        return fileName
    }
    
    /// 根据相对路径或文件名，读取物理附件数据。
    ///
    /// - Parameter fileName: 存储的唯一文件名
    /// - Returns: 物理文件的二进制数据，若文件不存在返回 nil
    public func loadMedia(fileName: String) -> Data? {
        let fileURL = attachmentsDirectoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
    
    /// 从沙盒中物理删除指定的附件。
    ///
    /// - Parameter fileName: 待删除的唯一文件名
    /// - Throws: 物理删除失败时抛出错误
    public func deleteMedia(fileName: String) throws {
        let fileURL = attachmentsDirectoryURL.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
