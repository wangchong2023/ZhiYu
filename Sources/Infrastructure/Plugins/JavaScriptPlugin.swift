//
//  JavaScriptPlugin.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统：JavaScript 沙箱、市场服务、插件注册与生命周期。
//
#if canImport(JavaScriptCore) && !os(watchOS)

import Foundation
import JavaScriptCore

/// 基于 JS 脚本的动态插件，已接入 PluginEnginePool 缓存连接池
final class JavaScriptPlugin: InterceptionPlugin {
    let manifest: PluginManifest
    let monetization: MonetizationInfo?
    
    /// 保存的脚本内容以备在借出的 context 中执行
    private let scriptContent: String
    private var pluginContext: PluginContext?
    
    init?(script: String, manifest: PluginManifest, monetization: MonetizationInfo? = nil) {
        self.manifest = manifest
        self.monetization = monetization
        self.scriptContent = script

        // 语法校验：确保 JS 在 JavaScriptCore 中可解析
        let tempContext = JSContext()
        tempContext?.exceptionHandler = { _, exception in
            // 语法错误会在 evaluateScript 之后立即触发
            Logger.shared.error("[JSPlugin: \(manifest.id)] Init syntax check failed: \(exception?.toString() ?? "unknown")")
        }
        tempContext?.evaluateScript(script)
        if let exc = tempContext?.exception {
            Logger.shared.error("[JSPlugin: \(manifest.id)] Rejected: \(exc.toString() ?? "nil")")
            return nil
        }

        Logger.shared.info("[JSPlugin: \(manifest.id)] Syntax validated OK")
    }
    
    /// 辅助方法：动态从池中租借 JSContext，装配 ZhiYu API 后执行，执行完后在 defer 中安全归还
    private func executeInContext<T>(_ body: (JSContext) throws -> T) throws -> T {
        let ctx = PluginEnginePool.shared.borrowContext()
        defer {
            PluginEnginePool.shared.returnContext(ctx)
        }
        
        // 1. 设置异常捕获器
        ctx.exceptionHandler = { [weak self] context, exception in
            guard let self = self else { return }
            if let context = context, let exception = exception {
                context.exception = exception
            }
            Logger.shared.error(" [JSPlugin: \(self.manifest.id)] Exception: \(exception?.toString() ?? "unknown")", error: nil)
        }
        
        // 2. 注入桥接好的 API
        setupAPI(in: ctx)

        // 2.2 核心安全加固：配置运行时看门狗护栏 (@SR-04)
        PluginSandboxGateway.configureWatchdog(for: ctx)

        // 加载插件脚本
        ctx.evaluateScript(self.scriptContent)
        if let exc = ctx.exception {
            Logger.shared.error("[JSPlugin: \(self.manifest.id)] Script evaluate failed: \(exc.toString() ?? "nil")")
            ctx.exception = nil
            throw PluginSandboxError.scriptSyntaxError(exc.toString() ?? "unknown")
        }
        
        // 4. 执行业务逻辑
        return try body(ctx)
    }
    
    /// 装配宿主为 JS 沙箱提供的标准 API 网关
    private func setupAPI(in context: JSContext) {
        guard let pluginCtx = self.pluginContext else { return }

        let jsContextObj: [String: Any] = [
            "log": unsafeBitCast(makeLogBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "registerCommand": unsafeBitCast(makeRegisterCommandBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "registerRibbonItem": unsafeBitCast(makeRegisterRibbonItemBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "registerSettingTab": unsafeBitCast(makeRegisterSettingTabBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "registerView": unsafeBitCast(makeRegisterViewBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "addEventListener": unsafeBitCast(makeAddEventListenerBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "saveData": unsafeBitCast(makeSaveDataBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "loadData": unsafeBitCast(makeLoadDataBlock(pluginCtx: pluginCtx), to: AnyObject.self),
            "fetch": unsafeBitCast(makeFetchBlock(pluginCtx: pluginCtx), to: AnyObject.self)
        ]
        context.setObject(jsContextObj, forKeyedSubscript: "ZhiYu" as NSString)
    }

    private func makeLogBlock(pluginCtx: PluginContext) -> @convention(block) (String) -> Void {
        { msg in DispatchQueue.main.async { pluginCtx.log(msg) } }
    }

    private func makeRegisterCommandBlock(pluginCtx: PluginContext) -> @convention(block) (String, String, String) -> Void {
        { [weak self] id, name, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                pluginCtx.registerCommand(id: id, name: name) {
                    try? self.executeInContext { ctx in
                        self.callJSFunction(funcName, in: ctx)
                    }
                }
            }
        }
    }

    private func makeRegisterRibbonItemBlock(pluginCtx: PluginContext) -> @convention(block) (String, String, String) -> Void {
        { [weak self] icon, title, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                pluginCtx.registerRibbonItem(icon: icon, title: title) {
                    try? self.executeInContext { ctx in
                        self.callJSFunction(funcName, in: ctx)
                    }
                }
            }
        }
    }

    private func makeRegisterSettingTabBlock(pluginCtx: PluginContext) -> @convention(block) (String, String?, String) -> Void {
        { [weak self] name, schema, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                pluginCtx.registerSettingTab(name: name, schema: schema) { data in
                    try? self.executeInContext { ctx in
                        if let jsFunc = ctx.objectForKeyedSubscript(funcName), !jsFunc.isUndefined {
                            jsFunc.call(withArguments: data.map { [$0] } ?? [])
                        }
                    }
                }
            }
        }
    }

    private func makeRegisterViewBlock(pluginCtx: PluginContext) -> @convention(block) (String, String, String, String) -> Void {
        { [weak self] id, title, icon, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                pluginCtx.registerView(id: id, title: title, icon: icon) {
                    try? self.executeInContext { ctx in
                        self.callJSFunction(funcName, in: ctx)
                    }
                }
            }
        }
    }

    private func makeAddEventListenerBlock(pluginCtx: PluginContext) -> @convention(block) (String, String) -> Void {
        { [weak self] event, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                pluginCtx.addEventListener(event: event) { _ in
                    try? self.executeInContext { ctx in
                        self.callJSFunction(funcName, in: ctx)
                    }
                }
            }
        }
    }

    private func makeSaveDataBlock(pluginCtx: PluginContext) -> @convention(block) (String, String) -> Void {
        { key, value in
            DispatchQueue.main.async {
                do {
                    try PluginSandboxGateway.auditStorage(key: key, value: value)
                    pluginCtx.saveData(key: key, value: value)
                } catch {
                    pluginCtx.log(" [DLP] saveData: \(error.localizedDescription)")
                }
            }
        }
    }

    private func makeLoadDataBlock(pluginCtx: PluginContext) -> @convention(block) (String) -> String? {
        { key in
            return runOnMainSync { pluginCtx.loadData(key: key) }
        }
    }

    private func makeFetchBlock(pluginCtx: PluginContext) -> @convention(block) (String, [String: Any]?, String) -> Void {
        { [weak self] url, options, funcName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                Task {
                    do {
                        let allowed = self.manifest.allowedDomains ?? []
                        let request = try PluginSandboxGateway.auditFetch(url: url, options: options, allowedDomains: allowed)
                        let (data, _) = try await URLSession.shared.data(for: request)
                        let responseString = String(data: data, encoding: .utf8) ?? ""
                        try? self.executeInContext { ctx in
                            JSGarbageCollect(ctx.jsGlobalContextRef)
                            self.callJSFunction(funcName, in: ctx, arguments: [responseString])
                        }
                    } catch {
                        pluginCtx.log(" [FetchError] \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func callJSFunction(_ name: String, in ctx: JSContext, arguments: [Any] = []) {
        if let jsFunc = ctx.objectForKeyedSubscript(name), !jsFunc.isUndefined {
            jsFunc.call(withArguments: arguments)
        }
    }
    
    /// on加载
    /// - Parameter context: context
    func onLoad(context: PluginContext) {
        self.pluginContext = context
        
        // 调用 JS onLoad (使用池化的 JSContext 并设置看门狗)
        try? executeInContext { ctx in
            if let onLoadFunc = ctx.objectForKeyedSubscript("onLoad"), !onLoadFunc.isUndefined {
                let group = JSContextGetGroup(ctx.jsGlobalContextRef)
                JSContextGroupSetExecutionTimeLimit(group, PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, { _, _ in return 1 }, nil)
                defer {
                    JSContextGroupSetExecutionTimeLimit(group, 0, nil, nil)
                    JSGarbageCollect(ctx.jsGlobalContextRef)
                }
                onLoadFunc.call(withArguments: [])
            }
        }
    }
    
    /// onUnload
    func onUnload() {
        try? executeInContext { ctx in
            if let onUnloadFunc = ctx.objectForKeyedSubscript("onUnload"), !onUnloadFunc.isUndefined {
                let group = JSContextGetGroup(ctx.jsGlobalContextRef)
                JSContextGroupSetExecutionTimeLimit(group, PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, { _, _ in return 0 }, nil)
                defer {
                    JSContextGroupSetExecutionTimeLimit(group, 0, nil, nil)
                    JSGarbageCollect(ctx.jsGlobalContextRef)
                }
                onUnloadFunc.call(withArguments: [])
            }
        }
        self.pluginContext = nil
    }
    
    private let maxResponseSize = PluginConstants.Sandbox.maxResponseSizeBytes
    
    /// pre处理
    /// - Parameter content: content
    /// - Returns: 字符串
    func preProcess(content: String) throws -> String {
        return try executeInContext { ctx in
            if let preProcessFunc = ctx.objectForKeyedSubscript("preProcess"), !preProcessFunc.isUndefined {
                let group = JSContextGetGroup(ctx.jsGlobalContextRef)
                JSContextGroupSetExecutionTimeLimit(group, PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, { _, _ in return 1 }, nil)
                
                defer {
                    JSContextGroupSetExecutionTimeLimit(group, 0, nil, nil)
                    JSGarbageCollect(ctx.jsGlobalContextRef)
                }
                
                let result = preProcessFunc.call(withArguments: [content])
                
                if let exception = ctx.exception {
                    ctx.exception = nil
                    throw PluginSandboxError.preProcessException(exception.toString() ?? "unknown")
                }

                let resultString = result?.toString() ?? content
                if resultString.count > maxResponseSize {
                    throw PluginSandboxError.payloadTooLarge
                }
                return resultString
            }
            return content
        }
    }
    
    /// post处理
    /// - Parameter content: content
    /// - Returns: 字符串
    func postProcess(content: String) throws -> String {
        return try executeInContext { ctx in
            if let postProcessFunc = ctx.objectForKeyedSubscript("postProcess"), !postProcessFunc.isUndefined {
                let group = JSContextGetGroup(ctx.jsGlobalContextRef)
                JSContextGroupSetExecutionTimeLimit(group, PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, { _, _ in return 1 }, nil)
                
                defer {
                    JSContextGroupSetExecutionTimeLimit(group, 0, nil, nil)
                    JSGarbageCollect(ctx.jsGlobalContextRef)
                }
                
                let result = postProcessFunc.call(withArguments: [content])
                
                if let exception = ctx.exception {
                    ctx.exception = nil
                    throw PluginSandboxError.postProcessException(exception.toString() ?? "unknown")
                }
                
                return result?.toString() ?? content
            }
            return content
        }
    }
}

#endif
