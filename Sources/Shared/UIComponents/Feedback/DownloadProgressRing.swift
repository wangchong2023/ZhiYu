//
//  DownloadProgressRing.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层 / UI 组件
//  核心职责：Apple Store 风格圆形下载进度环，支持下载中、暂停、校验、失败等状态。
//

import SwiftUI

/// Apple Store 风格圆形下载进度环
public struct DownloadProgressRing: View {
    let state: DownloadState
    let size: CGFloat

    @State private var lastProgress: Double = 0
    @State private var rotationAngle: Double = 0

    public init(state: DownloadState, size: CGFloat = DesignSystem.Metrics.ringSize) {
        self.state = state
        self.size = size
    }

    private var lineWidth: CGFloat {
        size * 0.11
    }

    private var clampedProgress: Double {
        if case .downloading(let p, _) = state {
            return min(max(p, 0), 1)
        }
        return lastProgress
    }

    private var isIndeterminate: Bool {
        switch state {
        case .pending, .verifying:
            return true
        default:
            return false
        }
    }

    private var progressColor: Color {
        switch state {
        case .failed:
            return .theme.red
        case .paused:
            return .orange
        case .cancelled:
            return .secondary
        default:
            return .appAccent
        }
    }

    public var body: some View {
        ZStack {
            trackCircle
            progressArc
            centerContent
        }
        .frame(width: size, height: size)
        .onChange(of: state) { _, newState in
            if case .downloading(let p, _) = newState {
                lastProgress = p
            }
        }
        .onAppear {
            if case .downloading(let p, _) = state {
                lastProgress = p
            }
            if isIndeterminate {
                startSpinning()
            }
        }
    }

    @ViewBuilder
    private var trackCircle: some View {
        Circle()
            .stroke(Color.appBorder.opacity(DesignSystem.Opacity.disabled), lineWidth: lineWidth)
    }

    @ViewBuilder
    private var progressArc: some View {
        if isIndeterminate {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(rotationAngle))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
        } else {
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.appStandard, value: clampedProgress)
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch state {
        case .downloading:
            percentageText(Int(clampedProgress * 100))
        case .paused:
            pauseIcon
        case .failed(let error):
            failedContent(error: error)
        case .verifying, .pending:
            EmptyView()
        case .completed:
            EmptyView()
        case .cancelled:
            EmptyView()
        }
    }

    private func percentageText(_ value: Int) -> some View {
        Text("\(value)%")
            .font(.system(size: size * 0.22, weight: .bold, design: .monospaced))
            .foregroundStyle(progressColor)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText())
    }

    private var pauseIcon: some View {
        Image(systemName: "pause.fill")
            .font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(.orange)
    }

    @ViewBuilder
    private func failedContent(error: String) -> some View {
        if error != "Not Downloaded" {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: size * 0.32))
                .foregroundStyle(.red)
        }
    }

    private func startSpinning() {
        guard isIndeterminate else { return }
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
}
