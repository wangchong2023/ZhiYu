//
//  HostingSetupSheet.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - Hosting Setup Sheet
/// 协作托管设置面板组件
/// 负责在发起 P2P 协作会话前配置房间名称、展示安全提示及启动服务监听
struct HostingSetupSheet: View {
    @ObservedObject var collabService: CollaborationService
    @Binding var roomName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.giant) {
                    headerIcon
                    titleText
                    roomNameField
                    infoSection
                    startButton
                }
                .padding()
            }
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(L10n.Collaboration.hostSession)
.appNavigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerIcon: some View {
        Image(systemName: DesignSystem.Icons.antenna)
            .font(.largeTitle)
            .foregroundStyle(.appAccent)
    }
    
    private var titleText: some View {
        Text(L10n.Collaboration.hostSetup)
            .font(.headline)
            .foregroundStyle(.appText)
    }
    
    private var roomNameField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            Text(L10n.Collaboration.roomName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)
            
            TextField(L10n.Collaboration.roomNamePlaceholder, text: $roomName)
                #if !os(watchOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .accessibilityIdentifier("hosting-room-name-field")
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.Collaboration.howItWorks)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)
            
            CollabInfoRow(icon: "wifi", text: L10n.Collaboration.info.local)
            CollabInfoRow(icon: DesignSystem.Icons.lockShieldFill, text: L10n.Collaboration.info.encrypted)
            CollabInfoRow(icon: DesignSystem.Icons.persons, text: L10n.Collaboration.info.maxPeers)
        }
        .padding()
        .appCardClip()
    }
    
    private var startButton: some View {
        AppFilledActionButton(title: L10n.Collaboration.startHosting) {
            let name = roomName.isEmpty ? L10n.Collaboration.room : roomName
            collabService.startHosting(roomName: name)
            dismiss()
        }
        .accessibilityIdentifier("hosting-start-button")
    }
}
