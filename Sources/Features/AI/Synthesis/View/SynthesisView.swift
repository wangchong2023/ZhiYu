//
//  SynthesisView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：合成视图入口容器，管理 Tab 切换、状态、文档列表与输出导航。
//

import SwiftUI

// MARK: - 合成视图入口

struct SynthesisView: View {
    @Binding var selection: SidebarSelection?
    @Binding var selectedTab: AppTab
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(SynthesisStore.self) var synthesisStore
    @EnvironmentObject var llmService: LLMService
    @ObservedObject var taskCenter = TaskCenter.shared
    @State private var showOutput = false
    @State private var outputType: SynthesisStore.SynthesisType = .mindmap
    @State private var selectedDoc: SynthesisStore.SynthesisDocument?
    @EnvironmentObject var themeManager: ThemeManager
    @State private var pdfURL: IdentifiableURL?

    @State private var exportError: String?
    @State private var showExportError = false
    @State private var docToRename: SynthesisStore.SynthesisDocument?
    @State private var newDocName = ""
    @State private var docToDelete: SynthesisStore.SynthesisDocument?
    @State private var showDeleteDocConfirm = false
    @State private var showRenameDialog = false
    
    @State private var editMode: SynthesisDocRow.EditMode = .inactive
    @State private var selectedDocIDs = Set<UUID>()
    @State private var showLimitAlert = false
    @State private var showNoPagesAlert = false
    @State private var expandedSynthesisSections: Set<SynthesisStore.SynthesisType> = Set(SynthesisStore.SynthesisType.allCases)
    @State private var showClearAllConfirm = false
    @State private var showBatchDeleteConfirm = false
    @State private var showLLMAlert = false
    @State private var selectedFilterType: SynthesisStore.SynthesisType?
    @State private var showPromptWorkshop = false

    var body: some View {
        @Bindable var synthesisStore = synthesisStore
        
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()
                
                mainList
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .appTabToolbar(title: L10n.AI.Synthesis.title)
            .synthesisViewPresentations(
                showOutput: $showOutput,
                pdfURL: $pdfURL,
                showNoPagesAlert: $showNoPagesAlert,
                showLimitAlert: $showLimitAlert,
                showRenameDialog: $showRenameDialog,
                showLLMAlert: $showLLMAlert,
                showBatchDeleteConfirm: $showBatchDeleteConfirm,
                showDeleteDocConfirm: $showDeleteDocConfirm,
                newDocName: $newDocName,
                docToRename: docToRename,
                docToDelete: docToDelete,
                batchDelete: batchDelete,
                onConfigureAI: { router.isShowingAISettingsSheet = true },
                synthesisStore: synthesisStore,
                outputSheet: outputSheet
            )
            .onTaskStatusChange(taskCenter)
            .task {
                await store.refresh()
            }
        }
    }

    private var mainList: some View {
        List {
            entrySection
            runningTasksContainer
            mainContentSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .padding(.top, DesignSystem.widePadding)
    }

    private var runningTasksContainer: some View {
        SynthesisTimelineView(taskCenter: taskCenter)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.standardPadding, bottom: DesignSystem.loosePadding, trailing: DesignSystem.standardPadding))
            .listRowBackground(Color.clear)
    }

    private var entrySection: some View {
        Section {
            synthesisEntryView
        }
        #if !os(watchOS)
        .listRowSeparator(.hidden)
        #endif
        .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.standardPadding, bottom: DesignSystem.loosePadding, trailing: DesignSystem.standardPadding))
        .listRowBackground(Color.clear)
    }

    private var mainContentSection: some View {
        Section {
            listHeader
                .listRowInsets(EdgeInsets(top: DesignSystem.medium, leading: DesignSystem.standardPadding, bottom: DesignSystem.small, trailing: DesignSystem.standardPadding))
            
            filterPillsBar
                .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.standardPadding, bottom: DesignSystem.small, trailing: DesignSystem.standardPadding))

            documentRows
        }
        #if !os(watchOS)
        .listRowSeparator(.hidden)
        #endif
        .listRowBackground(Color.clear)
    }

    private var filterPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Chip.spacing) {
                FilterPill(title: L10n.Search.all, isSelected: selectedFilterType == nil) {
                    withAnimation(.spring()) { selectedFilterType = nil }
                }
                ForEach(SynthesisStore.SynthesisType.allCases) { type in
                    FilterPill(title: type.title, icon: type.icon, color: type.formatColor, isSelected: selectedFilterType == type) {
                        withAnimation(.spring()) { selectedFilterType = type }
                    }
                }
            }
            .padding(.vertical, DesignSystem.tiny)
        }
    }

    private var filteredDocs: [(SynthesisStore.SynthesisType, SynthesisStore.SynthesisDocument)] {
        if let type = selectedFilterType {
            return synthesisStore.allSortedDocuments.filter { $0.0 == type }
        }
        return synthesisStore.allSortedDocuments
    }

    @ViewBuilder
    private var documentRows: some View {
        let docs = filteredDocs
        
        if docs.isEmpty {
            VStack(spacing: DesignSystem.medium) {
                Image(systemName: DesignSystem.Icons.weeklyInsight)
                    .font(.system(size: DesignSystem.Timeline.emptyIconSize))
                    .foregroundStyle(.appSecondary.opacity(DesignSystem.Metrics.emptyStateIconOpacity))
                Text(L10n.AI.Synthesis.noDocs)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                
                if selectedFilterType != nil {
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        withAnimation(.spring()) {
                            selectedFilterType = nil
                        }
                    }) {
                        HStack(spacing: DesignSystem.tiny) {
                            Text(L10n.Search.all)
                                .font(.caption.bold())
                            Image(systemName: "arrow.uturn.left")
                                .font(.caption2)
                        }
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.tightPadding)
                        .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.secondaryOpacity * 0.5)))
                        .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Metrics.emptyStateVerticalPadding)
            .appContainer(background: DesignSystem.containerMaterial)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.standardPadding, bottom: 0, trailing: DesignSystem.standardPadding))
        } else {
            ForEach(docs, id: \.1.id) { type, doc in
                SynthesisDocRow(
                    doc: doc,
                    type: type,
                    editMode: editMode,
                    isSelected: selectedDocIDs.contains(doc.id),
                    onTap: {
                        if editMode == .active {
                            if selectedDocIDs.contains(doc.id) {
                                selectedDocIDs.remove(doc.id)
                            } else {
                                selectedDocIDs.insert(doc.id)
                            }
                        } else {
                            selectedDoc = doc
                            showOutput = true
                        }
                    },
                    onRename: {
                        docToRename = doc
                        newDocName = doc.name
                        showRenameDialog = true
                    },
                    onDelete: {
                        docToDelete = doc
                        showDeleteDocConfirm = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: DesignSystem.standardPadding, bottom: 0, trailing: DesignSystem.standardPadding))
                .listRowBackground(
                    ZStack {
                        DesignSystem.containerMaterial
                        if doc.id != docs.last?.1.id {
                            VStack {
                                Spacer()
                                Divider()
                                    .background(Color.appBorder.opacity(DesignSystem.secondaryOpacity))
                                    .padding(.horizontal, DesignSystem.standardPadding)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.standardPadding)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                )
            }
        }
    }
    
    private var listHeader: some View {
        AppSectionHeader(
            title: L10n.AI.Synthesis.documentList,
            icon: "doc.text",
            trailing: AnyView(
                HStack(spacing: DesignSystem.medium) {
                    if editMode == .active {
                        Button(action: {
                            HapticFeedback.shared.trigger(.warning)
                            showBatchDeleteConfirm = true
                        }) {
                            Text(L10n.Common.delete)
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedDocIDs.isEmpty ? .appSecondary.opacity(DesignSystem.disabledOpacity) : .red)
                        }
                        .disabled(selectedDocIDs.isEmpty)
                        .buttonStyle(.plain)

                        Button(action: {
                            HapticFeedback.shared.trigger(.warning)
                            showClearAllConfirm = true
                        }) {
                            Text(L10n.Common.Misc.clear)
                                .font(.subheadline.bold())
                                .foregroundStyle(.appSecondary)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog(L10n.AI.Synthesis.clearAllConfirm, isPresented: $showClearAllConfirm, titleVisibility: .visible) {
                            Button(L10n.Common.Misc.clear, role: .destructive) {
                                synthesisStore.clearAll()
                                HapticFeedback.shared.trigger(.success)
                            }
                            Button(L10n.Common.cancel, role: .cancel) { }
                        }
                    }

                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        withAnimation(DesignSystem.standardAnimation) {
                            if editMode == .inactive {
                                editMode = .active
                            } else {
                                editMode = .inactive
                                selectedDocIDs.removeAll()
                            }
                        }
                    }) {
                        Text(editMode == .active ? L10n.Common.done : L10n.Common.edit)
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                }
            )
        )
        .padding(.horizontal, DesignSystem.tiny)
    }

    private func batchDelete() {
        HapticFeedback.shared.trigger(.warning)
        synthesisStore.batchDeleteSynthesisDocs(ids: selectedDocIDs)
        selectedDocIDs.removeAll()
        editMode = .inactive
        HapticFeedback.shared.trigger(.success)
    }
    
    @ViewBuilder
    private var outputSheet: some View {
        NavigationStack {
            Group {
                if let doc = selectedDoc {
                    SynthesisOutputContent(doc: doc)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let doc = selectedDoc, !doc.sourcePageIDs.isEmpty {
                    SynthesisSourcePagesBar(
                        sourcePageIDs: doc.sourcePageIDs,
                        store: store,
                        onNavigate: { pageID in
                            showOutput = false
                            if store.pages.contains(where: { $0.id == pageID }) {
                                router.selectedTab = .knowledge
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    router.navigateToPage(id: pageID)
                                }
                            } else {
                                ToastManager.shared.show(type: .info, message: L10n.AI.Synthesis.Error.pageNotFound)
                            }
                        }
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.done) { showOutput = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: DesignSystem.headlineFontSize) {
                        Button {
                            if let doc = selectedDoc {
                                AppPasteboard.string = doc.content
                                HapticFeedback.shared.trigger(.success)
                            }
                        } label: { Image(systemName: DesignSystem.Icons.copy) }

                        Button { exportAction() } label: { Image(systemName: DesignSystem.Icons.export) }
                    }
                }
            }
        }
    }

    private func exportAction() {
        guard let doc = selectedDoc else { return }
        Task {
            do {
                let url = try await synthesisStore.exportSynthesisDocument(doc)
                await MainActor.run { 
                    self.pdfURL = IdentifiableURL(url: url)
                    HapticFeedback.shared.trigger(.success) 
                }
            } catch {
                await MainActor.run { 
                    self.exportError = error.localizedDescription
                    self.showExportError = true 
                }
            }
        }
    }

    private var synthesisEntryView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            AppSectionHeader(
                title: L10n.AI.Synthesis.actions,
                icon: DesignSystem.Icons.wand,
                trailing: AnyView(
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        showPromptWorkshop = true
                    }) {
                        HStack(spacing: DesignSystem.tiny) {
                            Image(systemName: DesignSystem.Icons.promptWorkshop)
                            Text(L10n.AI.Prompt.Factory.title)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                    .buttonStyle(.plain)
                )
            )
            .padding(.horizontal, DesignSystem.tiny)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.medium) {
                ForEach(SynthesisStore.SynthesisType.allCases) { type in
                    SynthesisActionButton(type: type, 
                                         store: store, 
                                         showNoPagesAlert: $showNoPagesAlert, 
                                         showLimitAlert: $showLimitAlert,
                                         showLLMAlert: $showLLMAlert,
                                         selectedFilterType: $selectedFilterType,
                                         selectedDoc: $selectedDoc,
                                         showOutput: $showOutput)
                }
            }
            .appContainer(padding: true)
        }
        .sheet(isPresented: $showPromptWorkshop) {
            NavigationStack {
                PromptWorkshopView()
                    .navigationTitle(L10n.AI.Prompt.Factory.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.Common.done) { showPromptWorkshop = false }
                        }
                    }
            }
        }
    }
}

// MARK: - 辅助扩展：解耦 View Presentations

extension View {

    /// synthesisViewPresentations
    func synthesisViewPresentations(
        showOutput: Binding<Bool>,
        pdfURL: Binding<IdentifiableURL?>,
        showNoPagesAlert: Binding<Bool>,
        showLimitAlert: Binding<Bool>,
        showRenameDialog: Binding<Bool>,
        showLLMAlert: Binding<Bool>,
        showBatchDeleteConfirm: Binding<Bool>,
        showDeleteDocConfirm: Binding<Bool>,
        newDocName: Binding<String>,
        docToRename: SynthesisStore.SynthesisDocument?,
        docToDelete: SynthesisStore.SynthesisDocument?,
        batchDelete: @escaping () -> Void,
        onConfigureAI: @escaping () -> Void,
        synthesisStore: SynthesisStore,
        outputSheet: some View
    ) -> some View {
        self
            .sheet(isPresented: showOutput) { outputSheet }
            .sheet(item: pdfURL) { identifiable in
                #if !os(watchOS)
                PDFPreviewWrapper(url: identifiable.url)
                #else
                Text(identifiable.url.lastPathComponent)
                #endif
            }
            .synthesisAlerts(
                showNoPagesAlert: showNoPagesAlert,
                showLimitAlert: showLimitAlert,
                showRenameDialog: showRenameDialog,
                showLLMAlert: showLLMAlert,
                showBatchDeleteConfirm: showBatchDeleteConfirm,
                showDeleteDocConfirm: showDeleteDocConfirm,
                newDocName: newDocName,
                docToRename: docToRename,
                docToDelete: docToDelete,
                batchDelete: batchDelete,
                onConfigureAI: onConfigureAI,
                synthesisStore: synthesisStore
            )
    }

    private func synthesisAlerts(
        showNoPagesAlert: Binding<Bool>,
        showLimitAlert: Binding<Bool>,
        showRenameDialog: Binding<Bool>,
        showLLMAlert: Binding<Bool>,
        showBatchDeleteConfirm: Binding<Bool>,
        showDeleteDocConfirm: Binding<Bool>,
        newDocName: Binding<String>,
        docToRename: SynthesisStore.SynthesisDocument?,
        docToDelete: SynthesisStore.SynthesisDocument?,
        batchDelete: @escaping () -> Void,
        onConfigureAI: @escaping () -> Void,
        synthesisStore: SynthesisStore
    ) -> some View {
        self
            .alertNoPages(isPresented: showNoPagesAlert)
            .alertLimitReached(isPresented: showLimitAlert)
            .alertRenameDoc(isPresented: showRenameDialog, name: newDocName, doc: docToRename)
            .alertLLMNotConfigured(isPresented: showLLMAlert, onConfigure: onConfigureAI)
            .confirmBatchDelete(isPresented: showBatchDeleteConfirm, action: batchDelete)
            .alertDeleteDoc(isPresented: showDeleteDocConfirm, doc: docToDelete, store: synthesisStore)
    }

    /// alertLLMNotConfigured
    /// - Parameter isPresented: isPresented
    func alertLLMNotConfigured(isPresented: Binding<Bool>, onConfigure: @escaping () -> Void) -> some View {
        self.alert(L10n.Common.configureAI, isPresented: isPresented) {
            Button(L10n.ModelManager.Lab.configurations) {
                HapticFeedback.shared.trigger(.selection)
                onConfigure()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Common.configureAI)
        }
    }
}

extension View {

    /// alertNoPages
    /// - Parameter isPresented: isPresented
    func alertNoPages(isPresented: Binding<Bool>) -> some View {
        self.alert(L10n.AI.Synthesis.Error.noPages, isPresented: isPresented) {
            Button(L10n.Common.ok, role: .cancel) { }
        }
    }
    
    /// alertLimitReached
    /// - Parameter isPresented: isPresented
    func alertLimitReached(isPresented: Binding<Bool>) -> some View {
        self.alert(L10n.AI.Synthesis.Error.limitReached, isPresented: isPresented) {
            Button(L10n.Common.done, role: .cancel) { }
        }
    }
    
    /// alert重命名Doc
    /// - Parameter isPresented: isPresented
    /// - Parameter name: name
    /// - Parameter doc: doc
    func alertRenameDoc(isPresented: Binding<Bool>, name: Binding<String>, doc: SynthesisStore.SynthesisDocument?) -> some View {
        self.alert(L10n.Common.rename, isPresented: isPresented) {
            TextField(L10n.Tag.Management.inputName, text: name)
            Button(L10n.Common.rename) {
                if let doc = doc {
                    @Inject var store: SynthesisStore
                    store.renameSynthesisDoc(type: doc.type, docID: doc.id, newName: name.wrappedValue)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }
    
    /// confirmBatch删除
    /// - Parameter isPresented: isPresented
    /// - Parameter action: action
    /// - Returns: 视图
    func confirmBatchDelete(isPresented: Binding<Bool>, action: @escaping () -> Void) -> some View {
        self.confirmationDialog(L10n.AI.Synthesis.batchDeleteConfirm, isPresented: isPresented, titleVisibility: .automatic) {
            Button(L10n.Common.delete, role: .destructive) { action() }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }
    
    /// alert删除Doc
    /// - Parameter isPresented: isPresented
    /// - Parameter doc: doc
    func alertDeleteDoc(isPresented: Binding<Bool>, doc: SynthesisStore.SynthesisDocument?, store: SynthesisStore) -> some View {
        self.alert(L10n.Common.deleteConfirm, isPresented: isPresented) {
            Button(L10n.Common.delete, role: .destructive) {
                if let doc = doc {
                    store.deleteSynthesisDoc(type: doc.type, docID: doc.id)
                    HapticFeedback.shared.trigger(.success)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }
}
