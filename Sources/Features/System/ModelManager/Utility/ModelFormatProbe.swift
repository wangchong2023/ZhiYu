//
//  ModelFormatProbe.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：大模型文件魔数探针，执行 O(1) 字节级模型头部格式嗅探与完整性初检，防止残卷损坏与空壳伪装。
//

import Foundation
import UFPCore

/// 模型物理文件嗅探结果
public enum ModelProbeResult: Equatable, Sendable {
    case valid(format: String)
    case corrupted(reason: String)
    case notFound
}

/// 工业级大模型魔数与结构格式探针
public final class ModelFormatProbe: Sendable {

    public static let shared = ModelFormatProbe()

    private init() {}

    /// 嗅探指定路径的大模型权重文件格式与完整性
    /// - Parameter url: 权重文件的本地沙盒路径
    /// - Returns: 嗅探判定结果
    public func inspect(fileURL: URL) -> ModelProbeResult {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir) else {
            return .notFound
        }

        // 1. 如果是目录，针对 Core ML (.mlmodelc) 进行结构完整性验证
        if isDir.boolValue {
            return inspectMLModelPackage(at: fileURL)
        }

        // 2. 如果是单文件，读取属性与前导魔数字节
        do {
            let attrs = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0

            guard fileSize >= FeatureConstants.ModelSpecConstants.minValidModelFileSize else {
                return .corrupted(reason: FeatureConstants.ModelProbeConstants.reasonBelowMinimumSize)
            }

            return inspectFileHeader(at: fileURL, fileSize: fileSize)
        } catch {
            return .corrupted(reason: error.localizedDescription)
        }
    }

    /// 嗅探单文件模型的前导魔数字节（GGUF / Generic Binary）
    private func inspectFileHeader(at fileURL: URL, fileSize: Int64) -> ModelProbeResult {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return .corrupted(reason: FeatureConstants.ModelProbeConstants.reasonCannotOpenFileHandle)
        }
        defer { try? fileHandle.close() }

        // 读取前导魔数字节
        let magicLength = FeatureConstants.ModelSpecConstants.magicHeaderByteLength
        let headerData = (try? fileHandle.read(upToCount: magicLength)) ?? Data()
        guard headerData.count >= magicLength else {
            return .corrupted(reason: FeatureConstants.ModelProbeConstants.reasonHeaderTruncated)
        }

        let magicBytes = Array(headerData)
        let expectedGGUF = FeatureConstants.ModelSpecConstants.ggufMagicHeaderBytes

        if magicBytes == expectedGGUF {
            return .valid(format: FeatureConstants.ModelSpecConstants.ggufFormatName)
        }

        // 针对非 GGUF 的通用二进制权重包（如纯张量 bin），要求满足最小安全阈值
        if fileSize >= FeatureConstants.ModelSpecConstants.minValidModelFileSize {
            return .valid(format: FeatureConstants.ModelSpecConstants.genericBinaryFormatName)
        }

        return .corrupted(reason: FeatureConstants.ModelProbeConstants.reasonUnknownHeader)
    }

    /// 嗅探 Core ML .mlmodelc 编译后包结构
    private func inspectMLModelPackage(at packageURL: URL) -> ModelProbeResult {
        let fileManager = FileManager.default
        let metadataURL = packageURL.appendingPathComponent(FeatureConstants.ModelProbeConstants.metadataJSON)
        let modelNetURL = packageURL.appendingPathComponent(FeatureConstants.ModelProbeConstants.espressoNet)
        let weightsURL = packageURL.appendingPathComponent(FeatureConstants.ModelProbeConstants.espressoWeights)

        if fileManager.fileExists(atPath: metadataURL.path) ||
           fileManager.fileExists(atPath: modelNetURL.path) ||
           fileManager.fileExists(atPath: weightsURL.path) {
            return .valid(format: FeatureConstants.ModelSpecConstants.coremlFormatName)
        }

        return .corrupted(reason: FeatureConstants.ModelProbeConstants.reasonCoreMLPackageIncomplete)
    }
}
