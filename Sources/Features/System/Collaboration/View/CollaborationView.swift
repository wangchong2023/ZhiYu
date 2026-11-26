//
//  CollaborationView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Collaboration 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore
import Dependencies
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
import UFPDesignSystem
#endif

/// 协作视图常量
private enum CollaborationConstants {
    /// 头像图标尺寸 (iconDisplay * 1.16 ≈ 56)
    static let avatarIconSize: CGFloat = 56
}

// MARK: - 导航入口
/// 多设备协作功能主容器视图
/// 负责为协作内容提供独立的导航堆栈，管理 MultipeerConnectivity 的顶层生命周期
struct CollaborationView: View {
    var body: some View {
        CollaborationViewContent()
    }
}

// MARK: - 视图核心
/// 多设备协作核心业务视图
/// 负责 P2P 会话的建立（Host/Join）、邻近房间扫描、实时编辑流展示及成员状态监控
struct CollaborationViewContent: View {
    @StateObject private var collabService = CollaborationService()
    @Environment(AppStore.self) var store
    @Environment(\.interfaceIdiom) private var idiom
    @State private var roomName = ""
    @State private var userName = ""
    @State private var showHostingSheet = false
    @State private var showBrowsing = false
    @State private var showConnectionError = false

    @Dependency(\.deviceInfo) var deviceInfo: any DeviceInfoProtocol

    private var recentEditsSnapshot: [CollabEdit] {
        Array(collabService.recentEdits.suffix(DesignTokens.Metrics.maxCollabEditHistory)) // 10
    }

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = roomName
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.giant) {
                headerSection
                if collabService.isSimulator { simulatorWarning }
                statusSection

                if !collabService.isJoined {
                    actionSection
                    if showBrowsing { discoveredRoomsSection }
                } else {
                    sessionSection
                    peersSection
                    editsSection
                }
            }
            .frame(maxWidth: idiom == .mac ? DesignTokens.Metrics.macProfileWindowWidth : .infinity, alignment: .leading)
            .padding(idiom == .mac ? DesignTokens.Spacing.wide : DesignTokens.Spacing.standardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .appSubPageToolbar(title: L10n.Collaboration.title)
        .sheet(isPresented: $showHostingSheet) {
            HostingSetupSheet(collabService: collabService, roomName: $roomName)
                .appDesktopSheetSize(.compact)
        }
        .alert(L10n.Collaboration.Error.connectionTimeout, isPresented: $showConnectionError) {
            Button(L10n.Common.ok, role: .cancel) { }
        } message: {
            Text(collabService.connectionError ?? "")
        }
        .onAppear {
            userName = deviceInfo.deviceName
            collabService.setDelegate(store)
        }
        .onChange(of: collabService.connectionError) { _, newValue in
            showConnectionError = (newValue != nil)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.medium) { // 12
            Image(systemName: DesignTokens.Icons.personCircle)
                .font(.system(size: CollaborationConstants.avatarIconSize)) // 56
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appAccent, .appConcept],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(L10n.Collaboration.subtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignTokens.Spacing.small)
    }
    
    // MARK: - Simulator Warning
    private var simulatorWarning: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.warning)
                .foregroundStyle(Color.theme.orange)
            
            Text(L10n.Collaboration.simulatorWarning)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
        }
        .padding()
        .background(Color.theme.orange.opacity(DesignTokens.SystemOpacity.ghost)) // 0.08
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.card))
    }
    
    // MARK: - Status
    private var statusSection: some View {
        HStack(spacing: DesignTokens.Spacing.medium) { // 12
            Circle()
                .fill(collabService.isJoined ? Color.theme.green : Color.theme.gray)
                .frame(width: DesignTokens.Spacing.iconTiny, height: DesignTokens.Spacing.iconTiny) // 12
            
            Text(collabService.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            
            Spacer()
            
            if collabService.isJoined {
                Text("\(collabService.connectedPeers.count + 1)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, DesignTokens.Spacing.small) // 8
                    .padding(.vertical, DesignTokens.Spacing.tiny) // 4
                    .background(Color.appAccent.opacity(DesignTokens.Colors.Opacity.glassOpacity)) // 0.15
                    .clipShape(Capsule())
                    .foregroundStyle(.appAccent)
            }
        }
        .collabCardStyle()
    }

    // MARK: - Actions
    private var actionSection: some View {
        VStack(spacing: DesignTokens.Spacing.standardPadding) {
            usernameField
            if idiom == .mac {
                // macOS HIG：主/次操作采用紧凑尺寸水平并排，禁止全宽拉伸长条
                HStack(spacing: DesignTokens.Spacing.medium) {
                    joinButton
                    hostButton
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, DesignTokens.Spacing.tiny)
            } else {
                hostButton
                joinButton
            }
            if showBrowsing { stopSearchingButton }
        }
    }
    
    private var usernameField: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
            Text(L10n.Collaboration.username)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)

            HStack {
                Image(systemName: DesignTokens.Icons.person)
                    .foregroundStyle(.appAccent)
                TextField(L10n.Collaboration.usernamePlaceholder, text: $userName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .accessibilityIdentifier("collab-username-field")
                    .onChange(of: userName) { _, newValue in
                        collabService.setUserName(newValue)
                    }
            }
            .collabCardStyle()
        }
    }

    private var hostButton: some View {
        AppAdaptiveActionButton(
            title: L10n.Collaboration.hostSession,
            systemImage: DesignTokens.Icons.broadcast,
            style: .primary,
            isDisabled: collabService.isSimulator,
            desktopMinWidth: DesignTokens.Metrics.notebookCardWidth
        ) {
            showHostingSheet = true
        }
        .accessibilityIdentifier("collab-host-button")
    }

    private var joinButton: some View {
        AppAdaptiveActionButton(
            title: L10n.Collaboration.joinSession,
            systemImage: DesignTokens.Icons.search,
            style: .secondary,
            isDisabled: collabService.isSimulator,
            desktopMinWidth: DesignTokens.Metrics.notebookCardWidth
        ) {
            showBrowsing = true
            collabService.startBrowsing()
        }
        .accessibilityIdentifier("collab-join-button")
    }

    private var stopSearchingButton: some View {
        Button(action: {
            showBrowsing = false
            collabService.stop()
        }) {
            Text(L10n.Collaboration.stopSearching)
                .font(.subheadline)
                .foregroundStyle(Color.theme.red)
        }
        .accessibilityIdentifier("collab-stop-searching-button")
    }
    
    // MARK: - Discovered Rooms
    private var discoveredRoomsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(L10n.Collaboration.nearbyRooms)
                .font(.headline)
                .foregroundStyle(.appText)
            
            if collabService.discoveredRooms.isEmpty {
                HStack {
                    ProgressView()
                    Text(L10n.Collaboration.searching)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                }
                .collabCardStyle()
            } else {
                ForEach(collabService.discoveredRooms) { room in
                    DiscoveredRoomRow(room: room) {
                        collabService.joinRoom(room)
                    }
                }
            }
        }
    }
    
    // MARK: - Session Info
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack {
                Image(systemName: DesignTokens.Icons.crown)
                    .foregroundStyle(Color.theme.yellow)
                Text(collabService.roomName)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Spacer()
                CollabRoleBadge(role: collabService.role)
                    .accessibilityIdentifier("collab-role-badge")
            }
            .collabCardStyle()
            .accessibilityIdentifier("collab-session-info")

            leaveButton
        }
    }

    private var leaveButton: some View {
        HStack {
            if idiom == .mac { Spacer() }
            AppAdaptiveActionButton(
                title: L10n.Collaboration.leaveSession,
                systemImage: DesignTokens.Icons.errorCircle,
                style: .destructive
            ) {
                collabService.stop()
            }
            .accessibilityIdentifier("collab-leave-button")
        }
    }

    // MARK: - Peers
    private var peersSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(L10n.Collaboration.connectedUsers)
                .font(.headline)
                .foregroundStyle(.appText)
                .accessibilityIdentifier("collab-peers-header")

            // Self
            HStack {
                Image(systemName: DesignTokens.Icons.personCheck)
                    .foregroundStyle(Color.theme.green)
                Text(userName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                Spacer()
                Text(collabService.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
            .collabCardStyle()
            .accessibilityIdentifier("collab-self-peer")

            ForEach(collabService.connectedPeers) { peer in
                ConnectedPeerRow(peer: peer, showRole: false)
                    .accessibilityIdentifier("collab-peer-\(peer.id)")
            }
        }
    }
    
    // MARK: - Recent Edits
    private var editsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(L10n.Collaboration.recentEdits)
                .font(.headline)
                .foregroundStyle(.appText)
                .accessibilityIdentifier("collab-edits-header")

            if recentEditsSnapshot.isEmpty {
                Text(L10n.Collaboration.noEdits)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .collabCardStyle()
                    .accessibilityIdentifier("collab-no-edits")
            } else {
                ForEach(recentEditsSnapshot) { edit in
                    RecentEditRow(edit: edit)
                        .accessibilityIdentifier("collab-edit-\(edit.id)")
                }
            }
        }
    }
}
