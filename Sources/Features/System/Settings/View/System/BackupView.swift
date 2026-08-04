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
    @EnvironmentObject var themeManager: ThemeManager
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
                        Label(L10n.Backup.autoBackup, systemImage: "clock.arrow.circlepath")
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
                        backupService.createBackup(pages: store.pages)
                        HapticFeedback.shared.trigger(.selection)
                    } label: {
                        Label(L10n.Backup.createNow, systemImage: "plus.circle.fill")
                    }
                    
                    Button {
                        Task { await store.saveToDisk() }
                        backupService.markClean()
                    } label: {
                        Label(L10n.Backup.exportCurrent, systemImage: "square.and.arrow.up")
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
                            systemImage: "archivebox",
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
        backupService.createBackup(pages: store.pages)
        
        // Replace with backup data
        Task {
            await store.replaceAllPages(pages)
            await store.saveToDisk()
            HapticFeedback.shared.trigger(.success)
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
                    Label("\(entry.pageCount) " + L10n.Backup.pages, systemImage: "doc.richtext.fill")
                    Label("\(entry.totalWords) " + L10n.Backup.words, systemImage: "abc")
                    Label(entry.fileSize(in: backupDirectory), systemImage: "externaldrive")
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
                Label(L10n.Common.delete, systemImage: "trash")
            }
        }
    }
}
