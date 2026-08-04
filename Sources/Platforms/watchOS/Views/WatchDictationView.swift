//
//  WatchDictationView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：构建 WatchDictation 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore

// MARK: - 手表端语音采集
/// Apple Watch 语音笔记采集视图
/// 负责在手表端通过系统语音输入获取文本，并通过 WatchConnectivity 实时同步至主应用
struct WatchDictationView: View {
    @Environment(\.dismiss) private var dismiss
    @Inject private var watchSync: any WatchSyncProtocol
    @State private var text = ""
    
    var body: some View {
        VStack {
            TextField(L10n.Watch.dictateHint, text: $text)
                .padding()
            
            Spacer()
            
            HStack {
                Button(L10n.Common.cancel) { dismiss() }
                    .tint(.red)
                
                Button(L10n.Common.save) {
                    saveAndSync()
                }
                .tint(.green)
                .disabled(text.isEmpty)
            }
        }
        .navigationTitle(L10n.Watch.capture)
    }

    /// 保存听写内容并同步至 iPhone
    private func saveAndSync() {
        // 🛡️ 平台适配层解耦：手表端只充当采集端，通过 watchSync 管道将内容推送给配对的 iPhone 宿主
        // iPhone 宿主接收后会自动创建并持久化页面，从而避免在手表端加载整个 AppStore 及数据库
        watchSync.sendContent(text)

        // 触发手表端震动反馈
        WKInterfaceDevice.current().play(.success)
        
        dismiss()
    }
}
