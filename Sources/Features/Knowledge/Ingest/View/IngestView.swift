//
//  IngestView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Ingest 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore
import UniformTypeIdentifiers
import Dependencies

// MARK: - 视图核心
struct IngestView: View {
    @Environment(KnowledgeStore.self) var store
    @Environment(IngestStore.self) var ingestStore
    @Environment(Router.self) var router
    @EnvironmentObject var llmService: LLMService
    @Dependency(\.taskCenter) private var taskCenter
    @Environment(ThemeManager.self) var themeManager
    @Binding var selectedTab: AppTab
    
    // 使用专门的协调器管理状态与流程
    @State private var coordinator = IngestCoordinator()

    var body: some View {
        ZStack {
            themeManager.pageBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: DesignSystem.standardPadding + DesignSystem.small) {
                    ingestProgressPanel
                    actionsSection
                    ImportRecordSection(
                        onAITag: { record in coordinator.triggerAITagging(for: record) },
                        onManualEdit: { record in coordinator.openManualForm(with: record) }
                    )
                    if !taskCenter.tasks.filter({ $0.type == .ingest }).isEmpty { taskCenterLinkSection }
                    recentActivitiesSection
                }
                .padding(.horizontal)
                .padding(.top, DesignSystem.standardPadding)
                .padding(.bottom, DesignSystem.huge)
            }
        }
        .appTabToolbar(title: L10n.Ingest.title)
        .alert(L10n.Ingest.error, isPresented: $coordinator.showError) {
            Button(L10n.Ingest.ok) { coordinator.errorMessage = nil }
        } message: { Text(coordinator.errorMessage ?? "") }
        .alert(L10n.Common.configureAI, isPresented: $coordinator.showLLMAlert) {
            Button(L10n.ModelManager.Lab.configurations) {
                HapticFeedback.shared.trigger(.selection)
                router.isShowingAISettingsSheet = true
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Common.configureAI)
        }
        .fileImporter(
            isPresented: $coordinator.showFileImporter,
            allowedContentTypes: [.pdf, .text, .plainText, UTType("net.daringfireball.markdown")].compactMap({$0}),
            allowsMultipleSelection: true
        ) { coordinator.handleFileImport($0) }
        .sheet(isPresented: $coordinator.showVoiceNote, onDismiss: { if !coordinator.newTitle.isEmpty { coordinator.showManualForm = true } }) {
            VoiceNoteView(onFinish: { title, text, audioURL in
                coordinator.sourceHint = .voice
                coordinator.newTitle = title
                coordinator.newContent = text
                coordinator.manualFormTitle = L10n.Voice.Speech.title
                coordinator.pendingVoiceFileURL = audioURL
            })
        }
        .sheet(isPresented: $coordinator.showOCRScan, onDismiss: { if !coordinator.newTitle.isEmpty { coordinator.showManualForm = true } }) {
            OCRScanView(onFinish: { title, text, imageData in
                coordinator.sourceHint = .ocr
                coordinator.newTitle = title
                coordinator.newContent = text
                coordinator.manualFormTitle = L10n.Ingest.OCR.title
                if let data = imageData {
                    coordinator.pendingImageData = data
                }
            })
        }
        .sheet(isPresented: $coordinator.showURLImport) { URLImportSheet(urlText: $coordinator.newURL, onImport: { urls in coordinator.handleBatchURLImport(urls) }) }
        .sheet(isPresented: $coordinator.showManualForm) { manualFormSheet }
        .onReceive(NotificationCenter.default.publisher(for: .importFromClipboard)) { _ in coordinator.performClipboardImport() }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(PageBackgroundView(accentColor: .appSource))
    }

    /// 动态渲染的玻璃态 Ingest 细粒度子状态反馈面板
    private var ingestProgressPanel: some View {
        let runningIngestTasks = taskCenter.tasks.filter { $0.type == .ingest && isRunning(status: $0.status) }
        guard let activeTask = runningIngestTasks.first else { return AnyView(EmptyView()) }
        
        let (progress, currentStage) = {
            if case .running(let p, let s) = activeTask.status { return (p, s) }
            return (0.0, TaskStage.pending)
        }()
        
        return AnyView(
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                        Text(L10n.Ingest.smartIngest)
                            .font(.subheadline.bold())
                            .foregroundStyle(.appText)
                        Text(activeTask.target)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: DesignSystem.captionFontSize, weight: .bold, design: .monospaced))
                        .padding(.horizontal, DesignSystem.small)
                        .padding(.vertical, DesignSystem.tiny)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.glass))
                        .foregroundStyle(Color.appAccent)
                        .clipShape(Capsule())
                }
                
                Divider()
                
                IngestTimelineView(currentStage: currentStage, subLogs: activeTask.subLogs)
                    .padding(.top, DesignSystem.tiny)
            }
            .appContainer(padding: true)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .stroke(Color.appAccent.opacity(DesignSystem.Opacity.shadow), lineWidth: 1)
            )
            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.subtle), radius: 10, x: 0, y: 5)
        )
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            AppSectionHeader(title: L10n.Ingest.actions, icon: DesignSystem.Icons.trayArrowDown).padding(.horizontal, DesignSystem.tiny)
            IngestEntryCardsSection(
                showManualForm: Binding(get: { coordinator.showManualForm }, set: { if $0 { coordinator.sourceHint = .manual; coordinator.manualFormTitle = L10n.Ingest.manualEntry }; coordinator.showManualForm = $0 }),
                showOCRScan: $coordinator.showOCRScan, 
                newType: $coordinator.newType, 
                showFileImporter: $coordinator.showFileImporter, 
                showVoiceNote: $coordinator.showVoiceNote, 
                showURLImport: $coordinator.showURLImport,
                isLLMConfigured: coordinator.isLLMConfigured,
                onLLMNotConfigured: {
                    HapticFeedback.shared.trigger(.warning)
                    coordinator.showLLMAlert = true
                }
            )
            .appContainer(padding: true)
        }
    }

    private var taskCenterLinkSection: some View {
        Button(action: { HapticFeedback.shared.trigger(.selection); router.navigateToTool(.taskCenter) }) {
            HStack {
                Image(systemName: DesignSystem.Icons.history).font(.subheadline.bold()).foregroundStyle(.appAccent)
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    let runningCount = taskCenter.tasks.filter({ $0.type == .ingest && isRunning(status: $0.status) }).count
                    Text(L10n.Ingest.activeTasks(runningCount)).font(.caption.weight(.bold)).foregroundStyle(.appText)
                    Text(L10n.Ingest.recentActivity).font(.system(size: DesignSystem.microFontSize)).foregroundStyle(.appSecondary)
                }
                Spacer()
                Image(systemName: DesignSystem.Icons.forward).font(.caption2).foregroundStyle(.appSecondary)
            }
            .appContainer(padding: true)
        }.buttonStyle(.plain)
    }

    private var recentActivitiesSection: some View {
        let ingestTasks = taskCenter.tasks.filter { $0.type == .ingest }
        return VStack(alignment: .leading, spacing: DesignSystem.medium) {
            AppSectionHeader(title: L10n.Ingest.recent, icon: DesignSystem.Icons.listBulletRectangle).padding(.horizontal, DesignSystem.tiny)
            if ingestTasks.isEmpty {
                VStack(spacing: DesignSystem.tightPadding) {
                    Image(systemName: DesignSystem.Icons.clock).font(.title2).foregroundStyle(.appSecondary.opacity(DesignSystem.dimmedOpacity))
                    Text(L10n.Ingest.noActivities).font(.caption).foregroundStyle(.appSecondary)
                }.frame(maxWidth: .infinity).padding(.vertical, DesignSystem.loosePadding).appContainer()
            } else {
                VStack(spacing: 0) {
                    ForEach(ingestTasks.prefix(DesignSystem.Metrics.maxRecentItems)) { task in
                        ActivityRow(task: task)
                        if task.id != ingestTasks.prefix(DesignSystem.Metrics.maxRecentItems).last?.id { Divider().padding(.leading, DesignSystem.Metrics.largeIconBoxSize) }
                    }
                }.appContainer(padding: false)
            }
        }
    }

    private var manualFormSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.Creation.basicInfo)) {
                    TextField(L10n.Creation.pageTitle, text: $coordinator.newTitle).font(.headline)
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        Text(L10n.Creation.pageType).font(.caption.weight(.medium)).foregroundStyle(.appSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.small) {
                                // 遍历用户可见页面类型，屏蔽 raw 选项
                                ForEach(PageType.allVisibleCases, id: \.self) { type in
                                    Button(action: { HapticFeedback.shared.trigger(.selection); withAnimation(.spring(response: 0.3)) { coordinator.newType = type } }) {
                                        HStack(spacing: DesignSystem.tightPadding) { Image(systemName: type.icon); Text(type.displayName) }
                                        .font(.subheadline.weight(coordinator.newType == type ? .bold : .medium)).padding(.horizontal, DesignSystem.medium).padding(.vertical, DesignSystem.small)
                                        .background(coordinator.newType == type ? Color.fromModelColorName(type.colorName).opacity(DesignSystem.Opacity.medium) : Color.appCard.opacity(DesignSystem.Opacity.prominent))
                                        .foregroundStyle(coordinator.newType == type ? Color.fromModelColorName(type.colorName) : .appSecondary)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(coordinator.newType == type ? Color.fromModelColorName(type.colorName).opacity(DesignSystem.Opacity.shadow) : Color.appBorder, lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 1)
                        }
                    }.padding(.vertical, DesignSystem.tiny)
                    NavigationLink(destination: IconPickerView(selectedIcon: $coordinator.newCustomIcon)) {
                        HStack {
                            Label(L10n.Creation.customIcon, systemImage: DesignSystem.Icons.starSquareFill)
                            Spacer()
                            if let icon = coordinator.newCustomIcon { Image(systemName: icon).font(.title3).foregroundStyle(.appAccent).padding(DesignSystem.tiny).background(Color.appAccent.opacity(DesignSystem.Opacity.subtle)).clipShape(Circle())
                            } else { Text(L10n.Common.none).foregroundColor(.appSecondary).font(.subheadline) }
                        }
                    }
                    VStack(alignment: .leading, spacing: DesignSystem.small) {
                        HStack {
                            Label(L10n.Ingest.smartIngest, systemImage: DesignSystem.Icons.sparkles).font(.subheadline.bold()).foregroundStyle(.appAccent)
                            Spacer(); Toggle("", isOn: $coordinator.useSmartIngest).labelsHidden().tint(.appAccent)
                        }
                        if coordinator.useSmartIngest { Text(L10n.Ingest.smartIngestDesc).font(.system(size: DesignSystem.captionFontSize)).foregroundStyle(.appSecondary).lineLimit(2).fixedSize(horizontal: false, vertical: true) }
                    }.padding(.vertical, DesignSystem.tiny)
                }
                Section(header: Text(L10n.Creation.content)) {
                    Group {
                        // 这里使用全局环境注入的 appEnv 来判断交互样式
                        @Dependency(\.appEnvironment) var appEnv: any AppEnvironmentProtocol
                        if appEnv.interactionStyle == InteractionStyle.crown {
                            TextField("", text: $coordinator.newContent, axis: .vertical)
                        } else {
                            TextEditor(text: $coordinator.newContent)
                        }
                    }.frame(minHeight: DesignSystem.Metrics.heroValueSize * 7.7)
                }
            }
            .scrollContentBackground(.hidden).background(themeManager.pageBackground()).navigationTitle(coordinator.manualFormTitle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel) { coordinator.showManualForm = false }.buttonStyle(.plain) }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.Common.Misc.import) { coordinator.performIngest() }.disabled(coordinator.newTitle.isEmpty || coordinator.newContent.isEmpty || coordinator.isIngesting).buttonStyle(.plain) }
            }
        }
    }

    private func isRunning(status: TaskStatus) -> Bool { if case .running = status { return true }; return false }
}
