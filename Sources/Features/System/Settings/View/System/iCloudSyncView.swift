//
//  iCloudSyncView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 iCloudSync 界面的 UI 视图层组件。
//
#if ICLOUD_ENABLED
import SwiftUI

// MARK: - iCloud Sync Settings View
struct iCloudSyncView: View {
    @Environment(AppStore.self) var store
    @Environment(SettingsStore.self) var settingsStore

    @Bindable var coordinator: iCloudSyncCoordinator

    var body: some View {
        List {
            // MARK: - Status Section
            Section {
                SyncStatusRow(syncService: coordinator.syncService)
            } header: {
                Text(L10n.ICloud.syncStatus)
            }
            .appListRowBackground()

            // MARK: - Actions Section
            SyncActionsSection(
                syncService: coordinator.syncService,
                isSyncing: coordinator.isSyncing,
                onPush: coordinator.pushToCloud,
                onPullRequest: { coordinator.showPullConfirmation = true },
                onBidirectional: coordinator.bidirectionalSync
            )
            .appListRowBackground()

            // MARK: - Settings Section
            SyncSettingsSection(
                autoSync: $coordinator.autoSync,
                conflictResolution: $coordinator.conflictResolution,
                onAutoSyncChange: { enabled in
                    if enabled {
                        coordinator.startAutoSyncIfNeeded()
                    } else {
                        coordinator.cancelAutoSync()
                    }
                }
            )
            .appListRowBackground()

            // MARK: - Info Section
            Section {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    SyncInfoRow(icon: "1.circle.fill", text: L10n.ICloud.info1)
                    SyncInfoRow(icon: "2.circle.fill", text: L10n.ICloud.info2)
                    SyncInfoRow(icon: "3.circle.fill", text: L10n.ICloud.info3)
                    SyncInfoRow(icon: "4.circle.fill", text: L10n.ICloud.info4)
                }
                .padding(.vertical, DesignSystem.tiny)
            } header: {
                Text(L10n.ICloud.aboutSync)
            }
            .appListRowBackground()

            // MARK: - Danger Section
            Section {
                Button(role: .destructive) {
                    coordinator.showClearCloudConfirmation = true
                } label: {
                    Label(L10n.ICloud.clearCloudData, systemImage: DesignSystem.Icons.trashICloud)
                        .foregroundStyle(Color.theme.red)
                }
                .disabled(coordinator.isSyncing)
            }
            .appListRowBackground()
        }
        .adaptiveListStyle()
        .scrollContentBackground(.hidden)
        .background(PageBackgroundView(accentColor: .appAccent))
        .navigationTitle(L10n.ICloud.title)
        .alert(L10n.ICloud.syncError, isPresented: $coordinator.showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(coordinator.errorMessage)
        }
        .alert(L10n.ICloud.conflictDetected, isPresented: $coordinator.showConflictAlert) {
            Button(ConflictResolution.merge.displayName) {
                coordinator.conflictResolution = .merge
                settingsStore.iCloudConflictResolution = ConflictResolution.merge.rawValue
            }
            Button(ConflictResolution.keepLocal.displayName) {
                coordinator.conflictResolution = .keepLocal
                settingsStore.iCloudConflictResolution = ConflictResolution.keepLocal.rawValue
            }
            Button(ConflictResolution.keepRemote.displayName) {
                coordinator.conflictResolution = .keepRemote
                settingsStore.iCloudConflictResolution = ConflictResolution.keepRemote.rawValue
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.ICloud.conflictMessage)
        }
        .confirmationDialog(L10n.ICloud.pullWillOverwrite, isPresented: $coordinator.showPullConfirmation, titleVisibility: .visible) {
            Button(L10n.ICloud.download, role: .destructive) {
                coordinator.pullFromCloud()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.ICloud.pullOverwriteMessage)
        }
        .confirmationDialog(L10n.ICloud.clearCloudData, isPresented: $coordinator.showClearCloudConfirmation, titleVisibility: .visible) {
            Button(L10n.Common.Misc.clearAll, role: .destructive) {
                coordinator.clearCloudData()
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.ICloud.clearCloudDataMessage)
        }
        .alert(L10n.ICloud.autoSyncFailed, isPresented: $coordinator.showAutoSyncError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(coordinator.autoSyncErrorMessage)
        }
        .onAppear {
            coordinator.store = store
            coordinator.settingsStore = settingsStore
            coordinator.onAppear()
        }
        .onChange(of: coordinator.autoSync) { _, newValue in
            settingsStore.iCloudAutoSync = newValue
        }
        .onChange(of: coordinator.conflictResolution) { _, newValue in
            settingsStore.iCloudConflictResolution = newValue.rawValue
        }
        .sheet(item: $coordinator.activeConflict) { conflictInfo in
            ConflictDiffView(conflictInfo: conflictInfo, store: store)
        }
        .onDisappear {
            coordinator.onDisappear()
        }
    }
}
#endif // ICLOUD_ENABLED
