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
import UFPCore
import Dependencies
import UFPDesignSystem

@MainActor
/// 笔记本工作台视图
public struct NotebookHubView: View {
    // MARK: - 状态与环境
    
    @State private var viewModel = NotebookHubViewModel()
    @State private var showLintSheet = false   // 控制知识巡检面板弹出
    @Environment(Router.self) var router
    @Environment(ThemeManager.self) var themeManager
    @EnvironmentObject var onboardingService: OnboardingService
    @Dependency(\.appEnvironment) var appEnv: any AppEnvironmentProtocol // 注入环境能力
    @Environment(\.interfaceIdiom) private var idiom
    
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
                VStack(alignment: .leading, spacing: idiom == .mac ? DesignTokens.Spacing.wide : DesignTokens.Spacing.standardPadding) {
                    if idiom == .mac {
                        // macOS 方案 A：顶部统一工作台 Hero 条（含统计胶囊、紧凑搜索与新建主 CTA）
                        NotebookHubDesktopHeroBar(
                            viewModel: viewModel,
                            notebookCount: viewModel.notebooks.count,
                            totalPageCount: viewModel.notebooks.reduce(0) { $0 + $1.pageCount }
                        )
                    } else {
                        // 移动端/iPad：标准顶部搜索条
                        searchBar(bindableViewModel: Bindable(viewModel))
                    }
                    
                    AIProcessingStatusBanner()
                        .padding(.horizontal, DesignSystem.Vault.homePadding)

                    if !onboardingService.hasCompletedOnboarding {
                        WelcomeBannerView()
                            .environmentObject(onboardingService)
                            .padding(.horizontal, DesignSystem.Vault.homePadding)
                    }
                    notebookGridSection
                }
                .padding(.bottom, DesignTokens.Spacing.huge)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("NotebookHubView")
        }

        .navigationTitle(L10n.Vault.homeTitle)
        .appNavigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .appToolbarBackgroundVisible()
        .appToolbarBackgroundMaterial(.ultraThinMaterial)
        .toolbar {
            // 业务操作与头像按钮分置独立 ToolbarItem + 固定间距分隔，避免 macOS 26+ Liquid Glass 将视图切换按钮与头像融合成连体药丸。
            appToolbarTrailingGroup {
                sparklesButton
                if idiom != .watch {
                    sortMenu
                }
                displayModeButton
            }
            if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            appToolbarTrailing {
                UserProfileMenu()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("toggleDisplayMode"))) { _ in
            viewModel.toggleDisplayMode()
        }
        .sheet(isPresented: $viewModel.isShowingCreateSheet) {
            CreateNotebookSheet(viewModel: viewModel)
                .appDesktopSheetSize(.compact)
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            EditNotebookSheet(viewModel: viewModel)
                .appDesktopSheetSize(.compact)
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
            .appDesktopSheetSize(.large)
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
            Image(systemName: DesignTokens.Icons.search)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
            
            TextField(L10n.Search.base, text: bindableViewModel.searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            
            if !bindableViewModel.searchText.wrappedValue.isEmpty {
                Button { bindableViewModel.searchText.wrappedValue = "" } label: {
                    ClearSearchButton()
                }
            }
        }
        .commonContentPadding()
        .borderedCardStyle(
            horizontalPadding: DesignTokens.Spacing.standardPadding,
            verticalPadding: DesignTokens.SystemSpacing.elementLarge,
            backgroundOpacity: DesignTokens.SystemOpacity.glassStrong,
            cornerRadius: DesignTokens.Spacing.cardRadius
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius, style: .continuous)
                .strokeBorder(.appAccent.opacity(DesignTokens.Opacity.glass), lineWidth: 1)
        )
        .padding(.horizontal, DesignSystem.Vault.homePadding)
        .padding(.top, DesignTokens.Spacing.medium)
    }

    private var notebookGridSection: some View {
        Group {
            if viewModel.notebooks.isEmpty {
                AppEmptyState.withAction(
                    icon: DesignTokens.Icons.folderBadgePlus,
                    title: L10n.Vault.homeTitle,
                    description: nil,
                    actionLabel: L10n.Common.create,
                    actionRole: .primary
                ) {
                    viewModel.isShowingCreateSheet = true
                }
                .padding(.top, DesignTokens.Spacing.huge)
            } else if viewModel.displayMode == .grid {
                let columns = appEnv.screenClass == .expansive 
                    ? [GridItem(.adaptive(minimum: 280), spacing: DesignTokens.Spacing.standardPadding)]
                    : [GridItem(.flexible(), spacing: DesignTokens.Spacing.standardPadding), GridItem(.flexible(), spacing: DesignTokens.Spacing.standardPadding)]
                
                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.standardPadding) {
                    if idiom != .mac {
                        CreateNotebookButton(viewModel: viewModel, displayMode: .grid)
                    }
                    
                    ForEach(viewModel.notebooks) { notebook in
                        NotebookCard(notebook: notebook) {
                            viewModel.selectNotebook(notebook)
                        }
                    }
                }
            } else {
                VStack(spacing: DesignTokens.Spacing.medium) {
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
            Image(systemName: DesignTokens.Icons.sparkles)
                .font(.callout.weight(.bold))
                .foregroundStyle(.appAccent)
                .appToolbarItemStandardFrame()
        }
        .appToolbarButtonStyle()
    }
    
    private var displayModeButton: some View {
        Button(action: { viewModel.toggleDisplayMode() }) {
            Image(systemName: viewModel.displayMode.icon)
                .font(.system(size: DesignTokens.Typography.bodyFontSize))
                .foregroundStyle(.appSecondary)
                .appToolbarItemStandardFrame()
        }
        .appToolbarButtonStyle()
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            Group {
                Button(L10n.Vault.sort.date, systemImage: DesignTokens.Icons.sortDate) {
                    viewModel.sortOption = .date
                }
                
                Button(L10n.Vault.sort.name, systemImage: DesignTokens.Icons.sortName) {
                    viewModel.sortOption = .name
                }
            }
            .labelStyle(.titleAndIcon)
        } label: {
            Image(systemName: DesignTokens.Icons.sortUpDown)
                .font(.system(size: DesignTokens.Typography.bodyFontSize))
                .foregroundStyle(.appSecondary)
                .appToolbarItemStandardFrame()
        }
        .appToolbarButtonStyle()
        .visibleOniOSOrMac()
    }
}

/// 新用户欢迎横幅（不遮挡笔记本网格）
struct WelcomeBannerView: View {
    @EnvironmentObject var onboardingService: OnboardingService

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.sparkles)
                .font(.title2)
                .foregroundStyle(Color.theme.blue)
            VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
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
                Image(systemName: DesignTokens.Icons.xmark)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.Spacing.tightPadding)
                    .background(Color.secondary.opacity(DesignTokens.Opacity.subtle))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))
    }
}
