//
//  PDFConstants.swift
//  ZhiYu
//
//  系统层级：[L1] 基础设施层
//  核心职责：PDF 导入相关业务常量定义。
//

import Foundation

// MARK: - PDF 常量
public enum PDFConstants {
    /// 预览页数（全文模式提取前 N 页用于预览）
    public static let previewPageCount: Int = 2
    /// 预览文本最大长度（字符数）
    public static let previewTextLength: Int = 500
    /// 导入标签
    public static let ingestTag: String = "PDF"
}
