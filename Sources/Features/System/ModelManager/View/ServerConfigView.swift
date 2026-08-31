//
//  ServerConfigView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Mock 服务器配置管理视图，支持添加、编辑、测试、删除服务器配置。
//

import SwiftUI

/// Mock 服务器配置管理视图
@MainActor
public struct ServerConfigView: View {

    // MARK: - 环境注入

    @Environment(ThemeManager.self) private var themeManager

    // MARK: - 状态管理

    @State private var servers: [MockServerConfig] = []
    @State private var showAddSheet = false
    @State private var editingServer: MockServerConfig?

    public init() {}

    public var body: some View {
        ZStack {
            if servers.isEmpty {
                emptyStateView
            } else {
                serverList
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .sheet(isPresented: $showAddSheet) {
            ServerEditSheet(server: nil, onSave: { server in
                servers.append(server)
                saveServers()
            })
        }
        .sheet(item: $editingServer) { server in
            ServerEditSheet(server: server, onSave: { updated in
                if let index = servers.firstIndex(where: { $0.id == updated.id }) {
                    servers[index] = updated
                    saveServers()
                }
            })
        }
        .onAppear {
            loadServers()
        }
    }

    // MARK: - 子视图组件

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.large) {
            Image(systemName: DesignSystem.Icons.serverRack)
                .font(.system(size: ComponentSpacing.colossal)) // Dynamic Type
                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))

            Text(L10n.ModelManager.Server.emptyTitle)
                .font(.headline)
                .foregroundStyle(.appText)

            Text(L10n.ModelManager.Server.emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.large)

            Button(action: { showAddSheet = true }) {
                Label(L10n.ModelManager.Server.addServer, systemImage: DesignSystem.Icons.plus)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.large)
                    .padding(.vertical, DesignSystem.medium)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 服务器列表
    private var serverList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.medium) {
                ForEach(servers) { server in
                    serverCard(for: server)
                }
            }
            .padding(DesignSystem.medium)
        }
    }

    /// 服务器卡片
    /// 服务器卡片
    private func serverCard(for server: MockServerConfig) -> some View {
        ServerCardView(
            server: server,
            onTestConnection: { testConnection(for: server) },
            onEdit: { editingServer = server },
            onDelete: { deleteServer(server) },
            onSetDefault: { setDefaultServer(server) }
        )
    }

    /// 状态指示器
    private func statusIndicator(for server: MockServerConfig) -> some View {
        Circle()
            .fill(server.isHealthy ? Color.theme.green : Color.theme.red)
            .frame(width: DesignSystem.medium, height: DesignSystem.medium)
    }

    /// 添加按钮
    private var addButton: some View {
        Button(action: { showAddSheet = true }) {
            Image(systemName: DesignSystem.Icons.plus)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DesignSystem.Metrics.notebookActionIconSize, height: DesignSystem.Metrics.notebookActionIconSize)
                .background(Color.appAccent)
                .clipShape(Circle())
                .shadow(color: .primary.opacity(DesignSystem.Opacity.medium), radius: SystemShadow.radiusMedium, y: SystemShadow.offsetSmall)
        }
        .padding(DesignSystem.large)
    }

    // MARK: - 辅助方法

    private static let storageKey = "com.zhiyu.serverConfigs"

    private func saveServers() {
        guard let data = try? JSONEncoder().encode(servers) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode([MockServerConfig].self, from: data),
              !saved.isEmpty else {
            // 无已保存数据时使用示例配置
            servers = [
                MockServerConfig(
                    id: UUID(),
                    name: L10n.ModelManager.Server.mockLocalDev,
                    baseURL: APIPaths.localhostDefault,
                    apiKey: nil,
                    isDefault: true,
                    lastTestedAt: Date(),
                    latencyMs: 12,
                    isHealthy: true
                )
            ]
            return
        }
        servers = saved
    }

    private func testConnection(for server: MockServerConfig) {
        Task {
            let start = Date()
            let isHealthy: Bool
            let latency: Int
            if let url = URL(string: server.baseURL + "/health") {
                do {
                    let (_, response) = try await URLSession.shared.data(from: url)
                    isHealthy = (response as? HTTPURLResponse)?.statusCode == FeatureConstants.HTTPStatusCode.ok
                } catch {
                    isHealthy = false
                }
            } else {
                isHealthy = false
            }
            latency = Int(Date().timeIntervalSince(start) * Double(FeatureConstants.ServerConfig.latencyMsPerSecond))
            if let idx = servers.firstIndex(where: { $0.id == server.id }) {
                servers[idx] = MockServerConfig(
                    id: server.id, name: server.name, baseURL: server.baseURL,
                    apiKey: server.apiKey, isDefault: server.isDefault,
                    lastTestedAt: Date(), latencyMs: latency, isHealthy: isHealthy
                )
                saveServers()
            }
            HapticFeedback.shared.trigger(isHealthy ? .success : .error)
        }
    }

    private func deleteServer(_ server: MockServerConfig) {
        servers.removeAll { $0.id == server.id }
        saveServers()
    }

    private func setDefaultServer(_ server: MockServerConfig) {
        servers = servers.map { config in
            var updated = config
            updated.isDefault = (config.id == server.id)
            return updated
        }
        saveServers()
        HapticFeedback.shared.trigger(.success)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 服务器编辑 Sheet

private struct ServerEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager

    let server: MockServerConfig?
    let onSave: (MockServerConfig) -> Void

    @State private var name: String = ""
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var isDefault: Bool = false
    @State private var enableSSL: Bool = true
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()

                Form {
                    Section {
                        TextField(L10n.ModelManager.Server.formNameLabel, text: $name)
                        TextField(L10n.ModelManager.Server.formURLLabel, text: $baseURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        TextField(L10n.ModelManager.Server.formAPIKeyLabel, text: $apiKey)
                            .textInputAutocapitalization(.never)
                    }
                    .appListRowBackground()

                    Section {
                        Toggle(L10n.ModelManager.Server.formSetDefault, isOn: $isDefault)
                        Toggle(L10n.ModelManager.Server.formEnableSSL, isOn: $enableSSL)
                    }
                    .appListRowBackground()

                    Section {
                        Button(action: testConnection) {
                            HStack {
                                Spacer()
                                Text(L10n.ModelManager.Server.testConnection)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                        }

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains(L10n.ModelManager.Server.testSuccess) ? Color.theme.green : Color.theme.red)
                        }
                    }
                    .appListRowBackground()
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(server == nil ? L10n.ModelManager.Server.formAddTitle : L10n.ModelManager.Server.formEditTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.ModelManager.Server.formCancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.ModelManager.Server.formSave) {
                        saveServer()
                    }
                    .disabled(name.isEmpty || baseURL.isEmpty)
                }
            }
        }
        .onAppear {
            if let server = server {
                name = server.name
                baseURL = server.baseURL
                apiKey = server.apiKey ?? ""
                isDefault = server.isDefault
            }
        }
    }

    func testConnection() {
        guard let url = URL(string: baseURL + "/health") else {
            testResult = L10n.ModelManager.Server.testResult
            return
        }
        testResult = "\(L10n.ModelManager.Server.testResult)..."
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                let isHealthy = (response as? HTTPURLResponse)?.statusCode == FeatureConstants.HTTPStatusCode.ok
                await MainActor.run {
                    testResult = isHealthy ? "✅ Connected" : "❌ HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    HapticFeedback.shared.trigger(isHealthy ? .success : .error)
                }
            } catch {
                await MainActor.run {
                    testResult = "❌ \(error.localizedDescription)"
                    HapticFeedback.shared.trigger(.error)
                }
            }
        }
    }

    private func saveServer() {
        let newServer = MockServerConfig(
            id: server?.id ?? UUID(),
            name: name,
            baseURL: baseURL,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            isDefault: isDefault,
            lastTestedAt: Date(),
            latencyMs: 12,
            isHealthy: true
        )

        onSave(newServer)
        dismiss()
        HapticFeedback.shared.trigger(.success)
    }
}

// MARK: - MockServerConfig 模型

public struct MockServerConfig: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let baseURL: String
    public let apiKey: String?
    public var isDefault: Bool
    public let lastTestedAt: Date?
    public let latencyMs: Int?
    public let isHealthy: Bool

    public init(
        id: UUID,
        name: String,
        baseURL: String,
        apiKey: String?,
        isDefault: Bool,
        lastTestedAt: Date?,
        latencyMs: Int?,
        isHealthy: Bool
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.isDefault = isDefault
        self.lastTestedAt = lastTestedAt
        self.latencyMs = latencyMs
        self.isHealthy = isHealthy
    }
}

// MARK: - 预览

#if DEBUG
#Preview {
    ServerConfigView()
        .environment(ThemeManager())
}
#endif

// MARK: - 服务器卡片组件

/// 单个服务器配置卡片视图，展示状态、延迟等细节信息并提供快捷测试及配置动作
private struct ServerCardView: View {
    /// 绑定的服务器配置数据
    let server: MockServerConfig
    
    /// 测试连通性动作
    let onTestConnection: () -> Void
    
    /// 编辑服务器配置动作
    let onEdit: () -> Void
    
    /// 删除服务器动作
    let onDelete: () -> Void
    
    /// 设置默认服务器动作
    let onSetDefault: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            HStack {
                statusIndicator(for: server)

                VStack(alignment: .leading, spacing: SystemSpacing.tiny) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundStyle(.appText)

                    Text(server.baseURL)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if server.isDefault {
                    Image(systemName: DesignSystem.Icons.pinFill)
                        .foregroundStyle(Color.theme.orange)
                        .font(.caption)
                }
            }

            if let lastTested = server.lastTestedAt, let latency = server.latencyMs {
                HStack(spacing: SystemSpacing.tiny) {
                    Text(L10n.ModelManager.Server.lastTested(formatDate(lastTested)))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)

                    Text(FeatureConstants.Decorator.middleDot)
                        .foregroundStyle(.appSecondary)

                    Text(L10n.ModelManager.Server.latencyMs(latency))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }

            Divider()

            HStack(spacing: DesignSystem.medium) {
                Button(action: onTestConnection) {
                    Text(L10n.ModelManager.Server.testConnection)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appAccent)
                }

                Button(action: onEdit) {
                    Text(L10n.ModelManager.Server.editAction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appAccent)
                }

                Button(action: onDelete) {
                        Text(L10n.ModelManager.Server.deleteAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.theme.red)
                }

                Spacer()

                if !server.isDefault {
                    Button(action: onSetDefault) {
                        Text(L10n.ModelManager.Server.setDefaultAction)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.theme.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius)
                .stroke(server.isDefault ? Color.appAccent : Color.appBorder.opacity(DesignSystem.Opacity.shadow), lineWidth: server.isDefault ? 2 : 1)
        )
    }

    private func statusIndicator(for server: MockServerConfig) -> some View {
        Circle()
            .fill(server.isHealthy ? Color.theme.green : Color.theme.red)
            .frame(width: DesignSystem.medium, height: DesignSystem.medium)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
