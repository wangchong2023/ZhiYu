//
//  SynthesisViewActionHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：提供 AI 知识合成文档的名称清洗校验、分类筛选、多选状态机切换辅助
//

import Foundation
import UFPCore

/// 知识合成视图业务交互辅助工具
public enum SynthesisViewActionHelper {

    /// 校验并修剪重命名的文档名称
    /// - Parameter rawName: 用户输入的原始文档名
    /// - Returns: 修剪后的合法文档名称，为空或空白字符时返回 nil
    public static func validateAndTrimDocName(_ rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// 根据选定的合成类型过滤文档集合
    /// - Parameters:
    ///   - documents: 待过滤的全量文档列表
    ///   - filterType: 选中的过滤类型（为 nil 时表示全量）
    /// - Returns: 过滤后的文档列表
    public static func filterDocuments(
        _ documents: [(SynthesisStore.SynthesisType, SynthesisStore.SynthesisDocument)],
        by filterType: SynthesisStore.SynthesisType?
    ) -> [(SynthesisStore.SynthesisType, SynthesisStore.SynthesisDocument)] {
        guard let filter = filterType else { return documents }
        return documents.filter { $0.0 == filter }
    }

    /// 切换文档在多选集合中的选中状态
    /// - Parameters:
    ///   - docID: 文档 UUID
    ///   - selectedIDs: 正在维护的多选集合引用
    public static func toggleDocSelection(docID: UUID, in selectedIDs: inout Set<UUID>) {
        if selectedIDs.contains(docID) {
            selectedIDs.remove(docID)
        } else {
            selectedIDs.insert(docID)
        }
    }

    /// 判定是否允许执行批量删除操作
    /// - Parameter selectedIDs: 已勾选的文档 ID 集合
    /// - Returns: 是否可以触发批量删除
    public static func canBatchDelete(selectedIDs: Set<UUID>) -> Bool {
        !selectedIDs.isEmpty
    }
}
