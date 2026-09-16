//
//  PageHistoryView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 PageHistory 界面的 UI 视图层组件。
//
import SwiftUI
import Foundation

struct PageHistoryView: View {
    let page: any KnowledgePageRepresentable
    @Environment(AppStore.self) var store
    @State private var history: [SnapshotInfo] = []
    @State private var selectedSnapshot: SnapshotInfo?
    @State private var showRollbackAlert = false
    /// 用于临时保留待回滚的特定快照，避免 sheet 销毁导致目标丢失
    @State private var snapshotToRollback: SnapshotInfo?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    Text(L10n.Knowledge.Page.History.none)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history, id: \.id) { (snapshot: SnapshotInfo) in
                        Button(action: {
                            selectedSnapshot = snapshot
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(snapshot.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Localized.currentLocale)))
                                        .font(.subheadline.weight(.medium))
                                    Text(L10n.Knowledge.Page.History.physical)
                                        .font(.caption2)
                                        .foregroundStyle(.appSecondary)
                                }
                                Spacer()
                                Image(systemName: DesignSystem.Icons.forward)
                                    .font(.caption2)
                                    .foregroundStyle(.appTertiary)
                            }
                            .padding(.vertical, DesignSystem.tiny)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L10n.Knowledge.Page.History.title)
.appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .onAppear {
                history = store.snapshotService.getHistory(for: page.id)
            }
            .sheet(item: $selectedSnapshot) { snapshot in
                SnapshotDetailView(snapshot: snapshot) {
                    // 精准转移：在 selectedSnapshot 设空之前保留快照目标
                    snapshotToRollback = snapshot
                    selectedSnapshot = nil
                    showRollbackAlert = true
                }
            }
            .alert(L10n.Knowledge.Page.confirmDelete, isPresented: $showRollbackAlert) {
                Button(L10n.Knowledge.Page.History.rollback, role: .destructive) {
                    // 修正：使用选中的具体历史快照 snapshotToRollback 执行回滚，解决硬编码 history.first 导致其他快照失效的 bug
                    if let snapshot = snapshotToRollback, store.snapshotService.rollback(to: snapshot) != nil {
                        dismiss()
                    }
                }
                Button(L10n.Common.cancel, role: .cancel) { }
            } message: {
                Text(L10n.Knowledge.Page.History.rollback)
            }
        }
    }
}

struct SnapshotDetailView: View {
    let snapshot: SnapshotInfo
    let onRollback: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                        HStack {
                            Label(L10n.Knowledge.Page.History.version, systemImage: DesignSystem.Icons.clock)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.appAccent)
                            Spacer()
                            Text(snapshot.date.formatted(Date.FormatStyle(locale: Localized.currentLocale)))
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                        }
                        
                        Divider()
                        
                        if let content = try? String(contentsOf: snapshot.url, encoding: .utf8) {
                            Text(content)
                                .font(.body)
                        }
                    }
                    .padding()
                }
                
                VStack(spacing: DesignSystem.medium) {
                    AppFilledActionButton(title: L10n.Knowledge.Page.History.rollback, action: onRollback)
                    
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                }
                .padding()
                .background(Color.appBackground)
            }
            .navigationTitle(L10n.Knowledge.Page.History.title)
.appNavigationBarTitleDisplayMode(.inline)
        }
    }
}
