//
//  OnDeviceLLMServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 OnDeviceLLMService 模块的抽象契约接口。
//
import Foundation
import Combine

#if !os(watchOS)
/// 端侧本地大模型推理服务协议契约。
@MainActor
public protocol OnDeviceLLMServiceProtocol: ObservableObject, Sendable {
    /// 指示本地 Core ML 推理是否在当前硬件与 iOS 版本上可用
    var isAvailable: Bool { get }
    
    /// 指示当前大模型是否已完全成功载入内存
    var isModelLoaded: Bool { get }
    
    /// 指示模型当前是否正处于推理生成阻塞状态
    var isGenerating: Bool { get }
    
    /// 当前已载入内存的模型友好名称
    var loadedModelName: String { get }
    
    /// 全局扫描发现的可用本地/系统模型列表
    var availableModels: [OnDeviceModel] { get }
    
    /// 当前偏合选中的本地模型 ID
    var selectedModelID: String { get set }
    
    /// 文本生成过程的估计进度百分比 (0.0 ~ 1.0)
    var generationProgress: Double { get }
    
    /// 已生成文本的实时累积结果
    var generatedText: String { get }
    
    /// 当前推理生成速率（单位：tokens/秒）
    var inferenceSpeed: Double { get }
    
    /// 扫描内置 Bundle 资源及应用沙盒中的所有可用本地模型
    func discoverModels()
    
    /// 加载选中的 Core ML 语言模型到内存中
    func loadModel() async throws
    
    /// 执行端侧推理文本生成
    ///
    /// - Parameters:
    ///   - prompt: 提示词
    ///   - maxTokens: 最大 Token 长度上限
    /// - Returns: 生成的文本结果
    func generate(prompt: String, maxTokens: Int) async throws -> String
    
    /// 使用端侧模型进行多页面关联问答
    ///
    /// - Parameters:
    ///   - query: 查询文本
    ///   - pages: 关联的知识页面
    /// - Returns: 问答生成结果
    func chatOnDevice(query: String, pages: [KnowledgePage]) async throws -> String
    
    /// 取消当前的推理生成任务
    func cancelGeneration()
    
    /// 从内存中卸载当前大模型，释放系统资源
    func unloadModel()
    
    /// 从外部 URL 导入 Core ML 模型到沙盒
    ///
    /// - Parameter url: 模型文件的源路径 URL
    func importModel(from url: URL) async throws
    
    /// 从沙盒中物理删除指定的模型文件
    ///
    /// - Parameter model: 待删除的模型对象
    func deleteModel(_ model: OnDeviceModel) throws
}
#endif
