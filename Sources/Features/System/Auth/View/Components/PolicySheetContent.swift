// 系统层级：[L3] 表现层
// 核心职责: 隐私政策/服务条款通用弹窗组件，消除 AuthView 与 OverseasLoginCardView 的 policySheetContent 重复

import SwiftUI

/// 隐私政策 / 服务条款通用弹窗组件
///
/// 消除 `AuthView` 与 `OverseasLoginCardView` 中重复的
/// `NavigationStack { ZStack { themeManager.pageBackground(); ScrollView { Text(content) } } .navigationTitle(title) ... }` 模式。
@MainActor
struct PolicySheetContent: View {
    let title: String
    let content: String
    let isPresented: Binding<Bool>
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text(LocalizedStringKey(content))
                            .font(.body)
                            .foregroundStyle(.appText)
                            .lineSpacing(Spacing.tiny)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Localized.currentLocale)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { isPresented.wrappedValue = false }
                }
            }
        }
    }
}
