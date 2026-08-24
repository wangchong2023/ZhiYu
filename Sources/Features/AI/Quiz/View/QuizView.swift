//
//  QuizView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Quiz 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - 测评数据模型
/// 知识测评（Quiz）整体数据模型
/// 负责封装单次测评的所有题目及其元数据，支持 Codable 序列化以实现 AI 生成内容的解析
public struct QuizModel: Codable, Identifiable {
    public var id: String { title }
    public let title: String
    public let questions: [QuizQuestion]
}

/// 测评题目模型
/// 负责封装单条题目内容、备选项、正确答案索引及解析文本
public struct QuizQuestion: Codable, Identifiable {
    public let id: Int
    public let text: String
    public let options: [String]
    public let answer: Int
    public let explanation: String
}

// MARK: - 视图核心
/// 知识测评主视图
/// 负责展示 AI 生成的交互式选择题，并提供实时评分、动态答案解析、进度统计及完成反馈
struct QuizView: View {
    let quiz: QuizModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex = 0
    @State private var selectedOption: Int?
    @State private var showResult = false
    @State private var score = 0
    @State private var isCompleted = false
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            // 标题页眉
            Text(quiz.title)
                .font(.system(size: DesignSystem.titleFontSize, weight: .bold, design: .rounded))
                .padding(.top, Spacing.wide)
                .padding(.bottom, Spacing.small)
                .padding(.horizontal, Spacing.standardPadding)
                .frame(maxWidth: .infinity, alignment: .center)

            if !isCompleted {
                // 进度页眉
                VStack(spacing: Spacing.small) {
                    HStack {
                        Text(L10n.Quiz.questionFormat(currentIndex + 1, quiz.questions.count))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.appAccent)
                        Spacer()
                        Text(L10n.Quiz.scoreFormat(score))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.appSecondary)
                    }
                    
                    ProgressView(value: Double(currentIndex + 1), total: Double(quiz.questions.count))
                        .tint(.appAccent)
                }
                .padding(.horizontal, Spacing.standardPadding)
                
                // Question Content
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.wide) {
                        Text(quiz.questions[currentIndex].text)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.appText)
                            .lineSpacing(4)
                        
                        VStack(spacing: DesignSystem.medium) {
                            ForEach(0..<quiz.questions[currentIndex].options.count, id: \.self) { index in
                                OptionRow(
                                    label: optionLabel(for: index),
                                    text: quiz.questions[currentIndex].options[index],
                                    isSelected: selectedOption == index,
                                    isCorrect: quiz.questions[currentIndex].answer == index,
                                    showResult: showResult,
                                    action: {
                                        if !showResult {
                                            selectOption(index)
                                        }
                                    }
                                )
                            }
                        }
                        
                        if showResult {
                            let correctIdx = quiz.questions[currentIndex].answer
                            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                                HStack {
                                    Image(systemName: selectedOption == correctIdx ? DesignSystem.Icons.checkCircle : DesignSystem.Icons.errorCircle)
                                        .foregroundStyle(selectedOption == correctIdx ? Color.theme.green : Color.theme.red)
                                    Text(selectedOption == correctIdx ? L10n.Common.Misc.correct : L10n.Common.Misc.incorrect)
                                        .font(.subheadline.bold())
                                }

                                Text("\(optionLabel(for: correctIdx)) \(quiz.questions[currentIndex].options[correctIdx])")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)

                                Text(fixExplanationNumbering(quiz.questions[currentIndex].explanation, correctIndex: correctIdx))
                                    .font(.footnote)
                                    .foregroundStyle(.appSecondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.standardPadding)
                                    .background(Color.appAccent.opacity(DesignSystem.Opacity.ghost))
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Footer Action
                if showResult {
                    Button(action: nextQuestion) {
                        Text(currentIndex + 1 < quiz.questions.count ? L10n.Common.Misc.nextQuestion : L10n.Common.Misc.viewResults)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.standardPadding)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                            .shadow(color: .appAccent.opacity(DesignSystem.Opacity.shadow), radius: 10, y: 5)
                    }
                    .padding(Spacing.standardPadding)
                }
            } else {
                // Completion View
                VStack(spacing: DesignSystem.loosePadding) {
                    Image(systemName: DesignSystem.Icons.trophy)
                        .font(.system(size: DesignSystem.Metrics.heroValueSize * 2.5)) // 80
                        .foregroundStyle(.appAccent)
                    
                    VStack(spacing: DesignSystem.tightPadding) {
                        Text(L10n.Quiz.completed)
                            .font(.title.bold())
                        Text(L10n.Quiz.yourScore)
                            .font(.subheadline)
                            .foregroundStyle(.appSecondary)
                        Text("\(score) / \(quiz.questions.count)")
                            .font(.system(size: DesignSystem.Metrics.heroValueSize * 1.5, weight: .black, design: .rounded)) // 48
                            .foregroundStyle(.appAccent)
                    }
                    
                    Button(action: { dismiss() }) {
                        Text(L10n.Quiz.backToPage)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.standardPadding)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                    }
                    .padding(.horizontal, Spacing.huge)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
    }
    
    private func selectOption(_ index: Int) {
        withAnimation {
            selectedOption = index
            showResult = true
            if index == quiz.questions[currentIndex].answer {
                score += 1
            }
        }
    }
    
    private func optionLabel(for index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let i = letters.index(letters.startIndex, offsetBy: min(index, letters.count - 1))
        return "\(letters[i])."
    }

    /// 将解释文本中的数字答案引用替换为字母（如"1" → "A"）
    private func fixExplanationNumbering(_ explanation: String, correctIndex: Int) -> String {
        let letter = optionLabel(for: correctIndex).replacingOccurrences(of: ".", with: "")
        let targetNums = Set([correctIndex, correctIndex + 1])
        let pattern = "(||||||Correct Answer|Answer|Correct Option|Option|The answer is)[:\\s]*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return explanation }
        let nsRange = NSRange(explanation.startIndex..<explanation.endIndex, in: explanation)
        let matches = regex.matches(in: explanation, range: nsRange)
        var result = explanation
        for match in matches.reversed() {
            let numNSRange = match.range(at: 2)
            guard let numRange = Range(numNSRange, in: result),
                  let num = Int(result[numRange]),
                  targetNums.contains(num) else { continue }
            result.replaceSubrange(numRange, with: letter)
        }
        return result
    }

    private func nextQuestion() {
        if currentIndex + 1 < quiz.questions.count {
            withAnimation {
                currentIndex += 1
                selectedOption = nil
                showResult = false
            }
        } else {
            withAnimation {
                isCompleted = true
            }
        }
    }
}

// MARK: - 子组件
/// 测评选项行组件
/// 负责展示单个选项内容，并在提交后提供视觉化的正确/错误反馈
private struct OptionRow: View {
    let label: String
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("\(label) \(text)")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer()
                if showResult {
                    if isCorrect {
                        Image(systemName: DesignSystem.Icons.checkCircle)
                            .foregroundStyle(Color.theme.green)
                    } else if isSelected {
                        Image(systemName: DesignSystem.Icons.errorCircle)
                            .foregroundStyle(Color.theme.red)
                    }
                } else if isSelected {
                    Image(systemName: DesignSystem.Icons.checkCircle)
                        .foregroundStyle(.appAccent)
                }
            }
            .appContainer(
                background: backgroundColor,
                borderColor: borderColor,
                padding: true
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        if !showResult {
            return isSelected ? Color.appAccent.opacity(SystemOpacity.faint) : Color.appCard
        }
        if isCorrect { return Color.theme.green.opacity(SystemOpacity.faint) }
        if isSelected { return Color.theme.red.opacity(SystemOpacity.faint) }
        return Color.appCard
    }
    
    private var borderColor: Color {
        if !showResult {
            return isSelected ? .appAccent : .clear
        }
        if isCorrect { return Color.theme.green }
        if isSelected { return Color.theme.red }
        return .clear
    }
}
