//
//  PageDetailView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 PageDetail 界面的 UI 视图层组件。
//

import SwiftUI
import UFPCore

/// 页面详情视图
struct PageDetailView: View {
    let page: KnowledgePage
    @State private var coordinator: PageDetailCoordinator?
    var heroNamespace: Namespace.ID?
    @Environment(AppStore.self) var store
    @Environment(AIWorkflowStore.self) var aiStore
    @Environment(Router.self) var router
    @State private var recommendations: [KnowledgePage] = []
    @State private var copiedUrl: String?

    @Inject var pasteboard: any PasteboardProtocol
    @Inject var urlOpener: any URLOpenerProtocol

    /// 全局注入的平台设备环境，用于大屏适配判定
    private var appEnv: any AppEnvironmentProtocol {
        ServiceContainer.shared.resolve((any AppEnvironmentProtocol).self)
    }

    init(page: KnowledgePage, heroNamespace: Namespace.ID? = nil) {
        self.page = page
        self.heroNamespace = heroNamespace
    }
    
    private func pinButton(coordinator: PageDetailCoordinator) -> some View {
        Button(action: { Task { await coordinator.togglePin() } }) {
            Image(systemName: coordinator.page.isPinned ? DesignSystem.Icons.pinFill : DesignSystem.Icons.pin)
                .foregroundStyle(coordinator.page.isPinned ? .orange : .appSecondary)
        }
        .accessibilityIdentifier("pin")
    }
    
    private func backlinksButton(coordinator: PageDetailCoordinator) -> some View {
        Button(action: { coordinator.showBacklinks.toggle() }) {
            HStack(spacing: DesignSystem.tiny) {
                Image(systemName: DesignSystem.Icons.link)
                Text("\(coordinator.backlinks.count)")
            }
            .foregroundStyle(.appText)
        }
    }
    
    private func editButton(coordinator: PageDetailCoordinator) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            if coordinator.isEditing {
                Task { await store.updatePage(coordinator.page, forceDeepScan: false) }
            }
            coordinator.isEditing.toggle()
        }) {
            Image(systemName: coordinator.isEditing ? DesignSystem.Icons.check : DesignSystem.Icons.squareAndPencil)
                .foregroundStyle(coordinator.isEditing ? .green : .appText)
        }
    }
    
    private func aiMenuButton(coordinator: PageDetailCoordinator) -> some View {
        PageDetailAIMenuButton(
            isDisabled: coordinator.isEditing,
            onGenerateSummary: { coordinator.generateSummary() },
            onExtractActions: { coordinator.extractActions() },
            onMindmap: { coordinator.performSynthesis(type: .mindmap) },
            onQuiz: { coordinator.performSynthesis(type: .quiz) },
            onSlides: { coordinator.performSynthesis(type: .slides) },
            onReport: { coordinator.performSynthesis(type: .report) },
            onInfographic: { coordinator.performSynthesis(type: .infographic) },
            onShowSnapshotHistory: { coordinator.showSnapshotHistory = true },
            onExpandContent: { coordinator.expandContent() },
            onFindRelatedLinks: { coordinator.findRelatedLinks() }
        )
    }
    
    private var welcomeAhaPromptCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.small) {
                Image(systemName: DesignSystem.Icons.sparkles)
                    .font(.title2)
                    .foregroundStyle(LinearGradient(
                        colors: [.appAccent, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text(L10n.Common.Demo.Welcome.cardTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.appText)
            }
            
            Text(L10n.Common.Demo.Welcome.cardDesc)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                router.pendingInitialChatPrompt = L10n.Common.Demo.Welcome.prompt
                router.navigateToTool(.chat)
            }) {
                HStack(spacing: DesignSystem.small) {
                    Text("\(L10n.Common.Demo.Welcome.cardRecommend)\"\(L10n.Common.Demo.Welcome.prompt)\"")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Image(systemName: DesignSystem.Icons.arrowRight)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.small)
                .background(
                    LinearGradient(
                        colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.prominent)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .appAccent.opacity(DesignSystem.Opacity.shadow), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(DesignSystem.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(Color.appCard.opacity(DesignSystem.Opacity.dim))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(
                    LinearGradient(
                        colors: [.appAccent.opacity(DesignSystem.Opacity.disabled), .orange.opacity(DesignSystem.Opacity.medium)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .primary.opacity(DesignSystem.Opacity.ghost), radius: 10, x: 0, y: 5)
        .padding(.vertical, DesignSystem.medium)
    }
    
    var body: some View {
        if let coordinator = coordinator {
            mainDetailView(coordinator: coordinator)
        } else {
            Color.clear
                .onAppear {
                    self.coordinator = PageDetailCoordinator(page: page)
                }
        }
    }
    
    @ViewBuilder
    private func mainDetailView(coordinator: PageDetailCoordinator) -> some View {
        let content = ScrollViewReader { _ in
            detailScrollView(coordinator: coordinator)
        }
        .frame(maxWidth: DesignSystem.Layout.maxReadWidth)
        .frame(maxWidth: .infinity)
        .background(PageBackgroundView(accentColor: Color.fromModelColorName(coordinator.page.pageType.colorName)))
        .appSubPageToolbar(title: coordinator.page.title) {
            HStack(spacing: DesignSystem.small) {
                pinButton(coordinator: coordinator)
                backlinksButton(coordinator: coordinator)
                editButton(coordinator: coordinator)
                aiMenuButton(coordinator: coordinator)
            }
        }
        .safeAreaInset(edge: .top) {
            safeAreaHeader(coordinator: coordinator)
        }

        applyLifecycle(
            applySheetsAndModifiers(content, coordinator: coordinator),
            coordinator: coordinator
        )
    }

    private func detailScrollView(coordinator: PageDetailCoordinator) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: DesignSystem.mediumRadius)
                
                VStack(alignment: .leading, spacing: 0) {
                    PageDetailAISection(page: coordinator.page, onLinkTap: navigateToPage)
                        .id("aiResultSection")
                        .padding(.bottom, DesignSystem.standardPadding)
                    
                    Group {
                        PageDetailContentSection(
                            page: Binding(get: { coordinator.page }, set: { coordinator.page = $0 }),
                            isEditing: Binding(get: { coordinator.isEditing }, set: { coordinator.isEditing = $0 }),
                            onLinkTap: navigateToPage
                        )
                        
                        if coordinator.page.sourceURL != nil || coordinator.page.sourceType != nil {
                            sourceCitationBar(coordinator: coordinator)
                        }

                        if coordinator.page.title == L10n.Common.Demo.Welcome.title {
                            welcomeAhaPromptCard
                        }

                        potentialLinksSection(coordinator: coordinator)

                        Divider().background(Color.appBorder)
                        
                        PageDetailMetadataSection(page: coordinator.page, backlinks: coordinator.backlinks, recommendations: recommendations)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func safeAreaHeader(coordinator: PageDetailCoordinator) -> some View {
        VStack(spacing: 0) {
            if router.navigationHistory.count > 1 {
                BreadcrumbView(
                    history: Array(router.navigationHistory.dropLast()),
                    onNavigate: { id in
                        let targetPage = store.pages.first { $0.id == id }
                        if let target = targetPage {
                            navigateToPage(target.title)
                        }
                    },
                    onGoHome: {
                        router.popToRoot()
                        router.clearHistory()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            PageDetailHeader(page: coordinator.page, heroNamespace: heroNamespace)
                .padding(.top, router.navigationHistory.isEmpty ? DesignSystem.Layout.tightPadding : 0)
                .background(.ultraThinMaterial)
        }
        .padding(.top, appEnv.screenClass != .compact ? 36 : 0)
        .frame(maxWidth: DesignSystem.Layout.maxReadWidth)
        .overlay(
            Divider().background(Color.appBorder),
            alignment: .bottom
        )
    }

    private func applySheetsAndModifiers<V: View>(_ view: V, coordinator: PageDetailCoordinator) -> some View {
        view
            .confirmationDialog(L10n.Knowledge.Page.confirmDelete, isPresented: Binding(get: { coordinator.showDeleteConfirmation }, set: { coordinator.showDeleteConfirmation = $0 })) {
                let deleteTitle = L10n.Vault.Page.deletePageTitle(coordinator.page.title)
                Button(deleteTitle, role: .destructive) {
                    Task { await coordinator.deletePage() }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Knowledge.Page.deleteMessage)
            }
            .sheet(isPresented: Binding(get: { coordinator.showBacklinks }, set: { coordinator.showBacklinks = $0 })) {
                BacklinksView(page: coordinator.page)
            }
            .sheet(isPresented: Binding(get: { coordinator.showIconPicker }, set: { coordinator.showIconPicker = $0 })) {
                NavigationStack {
                    IconPickerView(selectedIcon: Binding(
                        get: { coordinator.page.customIcon },
                        set: { newIcon in
                            var updated = coordinator.page
                            updated.customIcon = newIcon
                            Task { await store.updatePage(updated, forceDeepScan: false) }
                            coordinator.page = updated
                        }
                    ))
                }
            }
            .sheet(isPresented: Binding(get: { coordinator.showSnapshotHistory }, set: { coordinator.showSnapshotHistory = $0 })) {
                PageHistoryView(page: coordinator.page)
            }
    }

    private func applyLifecycle<V: View>(_ view: V, coordinator: PageDetailCoordinator) -> some View {
        view
            .onChange(of: coordinator.page) { _, newValue in
                if !coordinator.isEditing {
                    Task { await store.updatePage(newValue, forceDeepScan: false) }
                }
            }
            .onAppear {
                router.addToHistory(coordinator.page)
                Task {
                    recommendations = await aiStore.findSimilarPages(for: coordinator.page)
                }
            }
            .onChange(of: coordinator.page) { _, newValue in
                router.addToHistory(newValue)
                Task {
                    recommendations = await aiStore.findSimilarPages(for: newValue)
                }
            }
            .quizPresentation(activeQuiz: Binding(get: { aiStore.activeQuiz }, set: { aiStore.activeQuiz = $0 }))
    }

    private func sourceCitationBar(coordinator: PageDetailCoordinator) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
            Label(L10n.Knowledge.Page.sourceCitation, systemImage: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.appSecondary)
            sourceCitationDetails(coordinator: coordinator)
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard.opacity(DesignSystem.Opacity.soft))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        .padding(.vertical, DesignSystem.tightPadding)
    }

    private func sourceCitationDetails(coordinator: PageDetailCoordinator) -> some View {
        HStack(spacing: DesignSystem.medium) {
            if let url = coordinator.page.sourceURL {
                sourceCitationLinkButton(url: url, coordinator: coordinator)
            }
            if let st = coordinator.page.sourceType {
                Label("\(L10n.Knowledge.Page.sourceTypeFile): \(st)", systemImage: "doc")
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
            if let fs = coordinator.page.fileSize {
                Text(ByteCountFormatter.string(fromByteCount: fs, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
        }
    }

    private func sourceCitationLinkButton(url: String, coordinator: PageDetailCoordinator) -> some View {
        Group {
            if coordinator.page.isLocalFileSource {
                Button(action: {
                    pasteboard.string = url
                    withAnimation(.spring()) {
                        copiedUrl = url
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(.spring()) {
                            if copiedUrl == url {
                                copiedUrl = nil
                            }
                        }
                    }
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Image(systemName: coordinator.page.displaySourceIcon)
                            .font(.caption2)
                        Text(copiedUrl == url ? L10n.Knowledge.Page.Source.copied : "\(coordinator.page.displaySourceName) (\(L10n.Knowledge.Page.Source.copyPath))")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    guard let urlObject = URL(string: url) else { return }
                    Task { await urlOpener.open(urlObject) }
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Image(systemName: coordinator.page.displaySourceIcon)
                            .font(.caption2)
                        Text(coordinator.page.displaySourceName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    private func navigateToPage(_ title: String) {
        if let target = store.pages.first(where: { $0.title == title }) {
            router.navigate(to: .pageDetail(id: target.id))
        }
    }

    @ViewBuilder
    private func potentialLinksSection(coordinator: PageDetailCoordinator) -> some View {
        let relevantLinks = aiStore.potentialLinks.filter { $0.sourcePageID == coordinator.page.id }
        
        Group {
            if aiStore.isScanningAI {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    HStack(spacing: DesignSystem.small) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.Knowledge.Page.AI.potentialLinksScanning)
                            .font(.subheadline)
                            .foregroundStyle(.appSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.largeRadius).fill(Color.appAccent.opacity(DesignSystem.Opacity.atomic)))
                    .padding(.vertical, DesignSystem.small)
                }
            } else if !relevantLinks.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    HStack(spacing: DesignSystem.small) {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(.appAccent)
                        Text(L10n.Knowledge.Page.AI.potentialLinksTitle)
                            .font(.headline)
                            .foregroundStyle(.appText)
                    }
                    .padding(.bottom, DesignSystem.tiny)
                    
                    VStack(spacing: DesignSystem.tightPadding) {
                        ForEach(relevantLinks) { link in
                            potentialLinkRow(link: link, store: store, aiStore: aiStore)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: DesignSystem.largeRadius).fill(Color.appAccent.opacity(DesignSystem.Opacity.atomic)))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.largeRadius)
                        .stroke(LinearGradient(colors: [.appAccent.opacity(DesignSystem.Opacity.medium), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
                .padding(.vertical, DesignSystem.small)
            } else if coordinator.hasScannedForLinks {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    HStack(spacing: DesignSystem.small) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.appSecondary)
                        Text(L10n.Knowledge.Page.AI.potentialLinksEmpty)
                            .font(.subheadline)
                            .foregroundStyle(.appSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.largeRadius).fill(Color.appCard.opacity(DesignSystem.Opacity.dim)))
                    .padding(.vertical, DesignSystem.small)
                }
            }
        }
    }

    @ViewBuilder
    private func potentialLinkRow(link: PotentialLinkSuggestion, store: AppStore, aiStore: AIWorkflowStore) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                HStack(spacing: DesignSystem.tiny) {
                    Text(link.sourceTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appText)
                    Image(systemName: DesignSystem.Icons.forward)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text("[[\(link.targetTitle)]]")
                        .font(.subheadline.bold())
                        .foregroundStyle(.appAccent)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await store.applyPotentialLink(link)
                    aiStore.removePotentialLink(id: link.id)
                    ToastManager.shared.show(type: .success, message: L10n.Lint.apply)
                }
            }) {
                Text(L10n.Lint.apply)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.medium)
                    .padding(.vertical, DesignSystem.tiny)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.tightPadding))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.tightPadding)
                .stroke(Color.appBorder.opacity(DesignSystem.glassOpacity), lineWidth: 1)
        )
    }
}
