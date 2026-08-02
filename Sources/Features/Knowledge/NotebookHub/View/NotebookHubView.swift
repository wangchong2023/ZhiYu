//
//  NotebookHubView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 NotebookHub 界面的 UI 视图层组件。
//
import SwiftUI

@MainActor
/// 笔记本工作台视图
public struct NotebookHubView: View {
    // MARK: - 状态与环境
    
    @State private var viewModel = NotebookHubViewModel()
    @State private var showLintSheet = false   // 控制知识巡检面板弹出
    @Environment(Router.self) var router
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingService: OnboardingService
    @Inject var appEnv: any AppEnvironmentProtocol // 注入环境能力
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - 视图主体
    
    public var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var router = router

        ZStack(alignment: .top) {
            // 统一背景系统：自动适配深浅模式与强调色
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                    // 1. 现代风格搜索区域
                    searchBar(bindableViewModel: Bindable(viewModel))
                    
                    AIProcessingStatusBanner()
                        .padding(.horizontal, DesignSystem.Vault.homePadding)

                    if !onboardingService.hasCompletedOnboarding {
                        WelcomeBannerView()
                            .environmentObject(onboardingService)
                            .padding(.horizontal, DesignSystem.Vault.homePadding)
                    }
                    notebookGridSection
                }
                .padding(.bottom, DesignSystem.huge)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("NotebookHubView")
        }

        .navigationTitle(L10n.Vault.homeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            // 使用 ToolbarItemGroup 替代 ToolbarItem + HStack，解决 SwiftUI 在大屏/分栏下 HStack 拦截点击、导致菜单及头像按钮点击无响应的交互缺陷。
            ToolbarItemGroup(placement: .topBarTrailing) {
                sparklesButton
                #if !os(watchOS)
                sortMenu
                #endif
                displayModeButton
                UserProfileMenu()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("toggleDisplayMode"))) { _ in
            viewModel.toggleDisplayMode()
        }
        .sheet(isPresented: $viewModel.isShowingCreateSheet) {
            CreateNotebookSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            EditNotebookSheet(viewModel: viewModel)
        }
        .alert(L10n.Common.rename, isPresented: $viewModel.isShowingRenameAlert) {
            TextField(L10n.Vault.namePlaceholder, text: $viewModel.editingName)
            Button(L10n.Common.cancel, role: .cancel) { }
            Button(L10n.Common.ok) {
                viewModel.confirmRename()
            }
        } message: {
            Text(L10n.Vault.renameMessage)
        }
        .environment(viewModel)
        // 以 sheet 弹出知识巡检视图（因 NotebookHub 的 NavigationStack 无 navigationDestination）
        .sheet(isPresented: $showLintSheet) {
            NavigationStack {
                LintWrapper()
                    .environment(router)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.Common.close) {
                                showLintSheet = false
                            }
                        }
                    }
            }
            .environment(router)
        }
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                onboardingService.nextStep()
            }
        }
    }
    
    // MARK: - 子视图组件
    
    private func searchBar(bindableViewModel: Bindable<NotebookHubViewModel>) -> some View {
        HStack {
            Image(systemName: DesignSystem.Icons.search)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
            
            TextField(L10n.Search.base, text: bindableViewModel.searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            
            if !bindableViewModel.searchText.wrappedValue.isEmpty {
                Button { bindableViewModel.searchText.wrappedValue = "" } label: {
                    Image(systemName: DesignSystem.Icons.errorCircle)
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                }
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.tightPadding + DesignSystem.atomic)
        .background(Color.appCard.opacity(DesignSystem.glassOpacity * 2))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                .strokeBorder(.appAccent.opacity(DesignSystem.Opacity.glass), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Vault.homePadding)
        .padding(.top, DesignSystem.medium)
    }

    private var notebookGridSection: some View {
        Group {
            if viewModel.notebooks.isEmpty {
                AppEmptyState.withAction(
                    icon: DesignSystem.Icons.folderBadgePlus,
                    title: L10n.Vault.homeTitle,
                    description: nil,
                    actionLabel: L10n.Common.create,
                    actionRole: .primary
                ) {
                    viewModel.isShowingCreateSheet = true
                }
                .padding(.top, DesignSystem.huge)
            } else if viewModel.displayMode == .grid {
                let columns = appEnv.screenClass == .expansive 
                    ? [GridItem(.adaptive(minimum: 250), spacing: DesignSystem.standardPadding)]
                    : [GridItem(.flexible(), spacing: DesignSystem.standardPadding), GridItem(.flexible(), spacing: DesignSystem.standardPadding)]
                
                LazyVGrid(columns: columns, spacing: DesignSystem.standardPadding) {
                    CreateNotebookButton(viewModel: viewModel, displayMode: .grid)
                    
                    ForEach(viewModel.notebooks) { notebook in
                        NotebookCard(notebook: notebook) {
                            viewModel.selectNotebook(notebook)
                        }
                    }
                }
            } else {
                VStack(spacing: DesignSystem.medium) {
                    CreateNotebookButton(viewModel: viewModel, displayMode: .list)
                    
                    ForEach(viewModel.notebooks) { notebook in
                        NotebookListRow(notebook: notebook) {
                            viewModel.selectNotebook(notebook)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Vault.homePadding)
    }
    
    private var sparklesButton: some View {
        Button {
            HapticFeedback.shared.trigger(.selection)
            showLintSheet = true
        } label: {
            Image(systemName: DesignSystem.Icons.sparkles)
                .font(.callout.weight(.bold))
                .foregroundStyle(.appAccent)
                .padding(.leading, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var displayModeButton: some View {
        Button(action: { viewModel.toggleDisplayMode() }) {
            Image(systemName: viewModel.displayMode.icon)
                .font(.system(size: DesignSystem.bodyFontSize))
                .foregroundStyle(.appSecondary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            Button {
                viewModel.sortOption = .date
            } label: {
                Label(L10n.Vault.sort.date, systemImage: DesignSystem.Icons.sortDate)
            }
            
            Button {
                viewModel.sortOption = .name
            } label: {
                Label(L10n.Vault.sort.name, systemImage: DesignSystem.Icons.sortName)
            }
        } label: {
            Image(systemName: DesignSystem.Icons.sortUpDown)
                .font(.system(size: DesignSystem.bodyFontSize))
                .foregroundStyle(.appSecondary)
        }
        .buttonStyle(.plain)
        .visibleOniOSOrMac()
    }
}

/// 新用户欢迎横幅（不遮挡笔记本网格）
struct WelcomeBannerView: View {
    @EnvironmentObject var onboardingService: OnboardingService

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Onboarding.pathTitle)
                    .font(.subheadline.bold())
                Text(L10n.Onboarding.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                HapticFeedback.shared.trigger(.selection)
                withAnimation { onboardingService.hasCompletedOnboarding = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(DesignSystem.tightPadding)
                    .background(Color.secondary.opacity(DesignSystem.Opacity.subtle))
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
    }
}
