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
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

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
    @State private var roomName = ""
    @State private var userName = ""
    @State private var showHostingSheet = false
    @State private var showBrowsing = false
    @State private var showConnectionError = false

    @Inject var deviceInfo: any DeviceInfoProtocol

    private var recentEditsSnapshot: [CollabEdit] {
        Array(collabService.recentEdits.suffix(DesignSystem.Metrics.maxCollabEditHistory)) // 10
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.giant) {
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
            .padding()
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .appSubPageToolbar(title: L10n.Collaboration.title)
        .sheet(isPresented: $showHostingSheet) {
            HostingSetupSheet(collabService: collabService, roomName: $roomName)
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
        VStack(spacing: DesignSystem.medium) { // 12
            Image(systemName: DesignSystem.Icons.personCircle)
                .font(.system(size: DesignSystem.iconDisplay * 1.16)) // 56
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
        .padding(.top, DesignSystem.small)
    }
    
    // MARK: - Simulator Warning
    private var simulatorWarning: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.warning)
                .foregroundStyle(.orange)
            
            Text(L10n.Collaboration.simulatorWarning)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
        }
        .padding()
        .background(Color.theme.orange.opacity(DesignSystem.glassOpacity * 0.53)) // 0.08
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
    }
    
    // MARK: - Status
    private var statusSection: some View {
        HStack(spacing: DesignSystem.medium) { // 12
            Circle()
                .fill(collabService.isJoined ? .green : .gray)
                .frame(width: DesignSystem.iconTiny, height: DesignSystem.iconTiny) // 12
            
            Text(collabService.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            
            Spacer()
            
            if collabService.isJoined {
                Text("\(collabService.connectedPeers.count + 1)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, DesignSystem.small) // 8
                    .padding(.vertical, DesignSystem.tiny) // 4
                    .background(Color.appAccent.opacity(DesignSystem.glassOpacity)) // 0.15
                    .clipShape(Capsule())
                    .foregroundStyle(.appAccent)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
    }
    
    // MARK: - Actions
    private var actionSection: some View {
        VStack(spacing: DesignSystem.medium) {
            usernameField
            hostButton
            joinButton
            if showBrowsing { stopSearchingButton }
        }
    }
    
    private var usernameField: some View {
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            Text(L10n.Collaboration.username)
                .font(.caption.weight(.medium))
                .foregroundStyle(.appSecondary)

            HStack {
                Image(systemName: DesignSystem.Icons.person)
                    .foregroundStyle(.appAccent)
                TextField(L10n.Collaboration.usernamePlaceholder, text: $userName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .accessibilityIdentifier("collab-username-field")
                    .onChange(of: userName) { _, newValue in
                        collabService.setUserName(newValue)
                    }
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        }
    }

    private var hostButton: some View {
        Button(action: { showHostingSheet = true }) {
            HStack {
                Image(systemName: DesignSystem.Icons.broadcast)
                Text(L10n.Collaboration.hostSession)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        }
        .disabled(collabService.isSimulator)
        .opacity(collabService.isSimulator ? 0.5 : 1.0)
        .accessibilityIdentifier("collab-host-button")
    }

    private var joinButton: some View {
        Button(action: {
            showBrowsing = true
            collabService.startBrowsing()
        }) {
            HStack {
                Image(systemName: DesignSystem.Icons.search)
                Text(L10n.Collaboration.joinSession)
            }
            .font(.headline)
            .foregroundStyle(.appAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        }
        .disabled(collabService.isSimulator)
        .opacity(collabService.isSimulator ? 0.5 : 1.0)
        .accessibilityIdentifier("collab-join-button")
    }

    private var stopSearchingButton: some View {
        Button(action: {
            showBrowsing = false
            collabService.stop()
        }) {
            Text(L10n.Collaboration.stopSearching)
                .font(.subheadline)
                .foregroundStyle(.red)
        }
        .accessibilityIdentifier("collab-stop-searching-button")
    }
    
    // MARK: - Discovered Rooms
    private var discoveredRoomsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
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
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
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
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack {
                Image(systemName: DesignSystem.Icons.crown)
                    .foregroundStyle(.yellow)
                Text(collabService.roomName)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Spacer()
                CollabRoleBadge(role: collabService.role)
                    .accessibilityIdentifier("collab-role-badge")
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            .accessibilityIdentifier("collab-session-info")

            leaveButton
        }
    }

    private var leaveButton: some View {
        Button(action: { collabService.stop() }) {
            HStack {
                Image(systemName: DesignSystem.Icons.errorCircle)
                Text(L10n.Collaboration.leaveSession)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.theme.red.opacity(DesignSystem.Opacity.light))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        }
        .accessibilityIdentifier("collab-leave-button")
    }

    // MARK: - Peers
    private var peersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.Collaboration.connectedUsers)
                .font(.headline)
                .foregroundStyle(.appText)
                .accessibilityIdentifier("collab-peers-header")

            // Self
            HStack {
                Image(systemName: DesignSystem.Icons.personCheck)
                    .foregroundStyle(.green)
                Text(userName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                Spacer()
                Text(collabService.role.displayName)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
            .accessibilityIdentifier("collab-self-peer")

            ForEach(collabService.connectedPeers) { peer in
                ConnectedPeerRow(peer: peer, showRole: false)
                    .accessibilityIdentifier("collab-peer-\(peer.id)")
            }
        }
    }
    
    // MARK: - Recent Edits
    private var editsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.Collaboration.recentEdits)
                .font(.headline)
                .foregroundStyle(.appText)
                .accessibilityIdentifier("collab-edits-header")

            if recentEditsSnapshot.isEmpty {
                Text(L10n.Collaboration.noEdits)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
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
