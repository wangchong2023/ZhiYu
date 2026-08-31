//
//  BackupView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Backup 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - Backup & Recovery View
struct BackupView: View {
    @Environment(AppStore.self) var store
    @StateObject private var backupService = BackupService()
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreConfirmation = false
    @State private var selectedEntry: BackupService.BackupEntry?
    @State private var showCreateBackup = false
    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: BackupService.BackupEntry?
    
    var body: some View {
        NavigationStack {
            List {
                // Auto Backup Toggle
                Section {
                    Toggle(isOn: $backupService.isAutoBackupEnabled) {
                        Label(L10n.Backup.autoBackup, systemImage: DesignSystem.Icons.history)
                    }
                    
                    if let lastDate = backupService.lastBackupDate {
                        HStack {
                            Text(L10n.Backup.lastBackup)
                                .foregroundStyle(.appSecondary)
                            Spacer()
                            Text(lastDate.formatted(Date.FormatStyle(date: .numeric, time: .standard, locale: Localized.currentLocale)))
                                .foregroundStyle(.appSecondary)
                        }
                    }
                } header: {
                    Text(L10n.Backup.settings)
                }
                .appListRowBackground()
                
                // Manual Actions
                Section {
                    Button {
                        // Bug #56 修复：手动"立即创建备份"必须绕过自动备份开关与节流，
                        // 否则在 isAutoBackupEnabled=false 时按钮静默失效。
                        backupService.createForcedBackup(pages: store.pages)
                        HapticFeedback.shared.trigger(.selection)
                    } label: {
                        Label(L10n.Backup.createNow, systemImage: DesignSystem.Icons.plusCircle)
                    }
                    
                    Button {
                        Task { await store.saveToDisk() }
                        backupService.markClean()
                    } label: {
                        Label(L10n.Backup.exportCurrent, systemImage: DesignSystem.Icons.export)
                    }
                } header: {
                    Text(L10n.Backup.actions)
                }
                .appListRowBackground()
                
                // Backup History
                Section {
                    if backupService.backupEntries.isEmpty {
                        ContentUnavailableView(
                            L10n.Backup.noBackups,
                            systemImage: DesignSystem.Icons.archiveboxOutline,
                            description: Text(L10n.Backup.noBackupsDesc)
                        )
                    } else {
                        ForEach(backupService.backupEntries) { entry in
                            BackupEntryRow(entry: entry, backupDirectory: backupService.backupDirectory) {
                                selectedEntry = entry
                                showRestoreConfirmation = true
                            } onDelete: {
                                HapticFeedback.shared.trigger(.warning)
                                backupToDelete = entry
                                showDeleteConfirmation = true
                            }
                        }
                    }
                } header: {
                    Text(L10n.Backup.history)
                }
                .appListRowBackground()
            }
            .insetGroupedListStyleIfIOS()
            .scrollContentBackground(.hidden)
            .background(themeManager.pageBackground())
            .navigationTitle(L10n.Backup.title)
.appNavigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                L10n.Backup.restoreTitle,
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Backup.restore, role: .destructive) {
                    restoreFromBackup()
                }
                Button(L10n.Common.cancel, role: .cancel) { selectedEntry = nil }
            } message: {
                Text(L10n.Backup.restoreMessage)
            }
            .confirmationDialog(
                L10n.Backup.deleteConfirmTitle,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.delete, role: .destructive) {
                    if let entry = backupToDelete {
                        backupService.deleteBackup(entry)
                        HapticFeedback.shared.trigger(.success)
                    }
                    backupToDelete = nil
                }
                Button(L10n.Common.cancel, role: .cancel) { backupToDelete = nil }
            } message: {
                Text(L10n.Backup.deleteConfirmMessage)
            }
        }
    }
    
    private func restoreFromBackup() {
        guard let entry = selectedEntry,
              let pages = backupService.restoreBackup(entry) else { return }

        // Save current state first (as a safety backup)
        // Bug #57 修复：恢复前的安全备份必须绕过自动备份开关与节流，
        // 否则用户关闭自动备份或刚做过备份时，安全备份被静默吞掉，导致数据丢失。
        backupService.createForcedBackup(pages: store.pages)

        // Replace with backup data
        Task {
            await store.replaceAllPages(pages)
            await store.saveToDisk()
            HapticFeedback.shared.trigger(.success)
            // Bug #78 修复：恢复成功后清空 selectedEntry，避免状态泄漏到下次操作。
            await MainActor.run { selectedEntry = nil }
        }
    }
}

// MARK: - Backup Entry Row
struct BackupEntryRow: View {
    let entry: BackupService.BackupEntry
    let backupDirectory: URL
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.archive)
                .font(.title3)
                .foregroundStyle(.appAccent)
            
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                
                HStack(spacing: DesignSystem.medium) {
                    Label("\(entry.pageCount) " + L10n.Backup.pages, systemImage: DesignSystem.Icons.docRichtext)
                    Label("\(entry.totalWords) " + L10n.Backup.words, systemImage: DesignSystem.Icons.sortName)
                    Label(entry.fileSize(in: backupDirectory), systemImage: DesignSystem.Icons.externaldrive)
                }
                .font(.caption)
                .foregroundStyle(.appSecondary)
            }
            
            Spacer()
            
            Button {
                onRestore()
            } label: {
                Image(systemName: DesignSystem.Icons.undo)
                    .foregroundStyle(.appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DesignSystem.tiny)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L10n.Common.delete, systemImage: DesignSystem.Icons.delete)
            }
        }
    }
}
