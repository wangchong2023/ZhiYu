//
//  AgreementCheckboxView.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 - 共享组件
//  核心职责：提取登录流程中用户协议勾选区域的共享视图，消除 OverseasLoginCardView 与 AuthPhonePanel 之间的重复代码。
//

import SwiftUI
import UFPCore

/// 用户协议勾选区域共享组件
///
/// 包含勾选圆圈按钮、协议文本（支持富文本链接跳转）与未勾选提示。
/// 被 `OverseasLoginCardView` 和 `AuthPhonePanel` 共同复用。
struct AgreementCheckboxView: View {
    @Binding var isAgreementChecked: Bool
    @Binding var showTermsSheet: Bool
    @Binding var showPrivacySheet: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.tightPadding) {
            Button(action: {
                withAnimation { isAgreementChecked.toggle() }
            }) {
                Image(systemName: isAgreementChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isAgreementChecked ? Color.appAccent : Color.appSecondary)
                    .font(.system(size: Spacing.smallIconSize))
            }
            .accessibilityIdentifier("agreementCheckbox")
            .accessibilityValue(isAgreementChecked ? "checked" : "unchecked")

            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(LocalizedStringKey(L10n.Auth.agreementText))
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
                    .lineSpacing(Spacing.atomic)
                    .environment(\.openURL, OpenURLAction { url in
                        if url.scheme == FeatureConstants.URLSchemeName.privacy {
                            if url.host == FeatureConstants.URLSchemeName.terms {
                                showTermsSheet = true
                            } else {
                                showPrivacySheet = true
                            }
                            return .handled
                        }
                        return .systemAction
                    })

                if !isAgreementChecked {
                    Text(L10n.Auth.pleaseCheckAgreement)
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .padding(.horizontal, Spacing.small)
    }
}
