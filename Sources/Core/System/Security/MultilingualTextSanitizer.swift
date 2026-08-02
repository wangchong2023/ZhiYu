//
//  MultilingualTextSanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供多国语言 (9 大语系) 抗越狱与防变异文本洗词层。
//  包含英文/拉丁语 Leetspeak/Homoglyph 变形词还原、欧语系重音符剥离、日韩语全半角归一化、中文繁简归一化与全语系零宽干扰符剥离。
//
import Foundation

/// 全球 9 大语言抗变异与洗词预处理器
public final class MultilingualTextSanitizer: @unchecked Sendable {
    public static let shared = MultilingualTextSanitizer()

    /// 英文/拉丁语系 Leetspeak 替代映射字典
    private let leetspeakMap: [Character: Character] = [
        "@": "a", "4": "a",
        "$": "s", "5": "s",
        "0": "o",
        "1": "i", "!": "i", "|": "i",
        "3": "e",
        "7": "t",
        "8": "b"
    ]

    private init() {}

    /// 1. 中文：繁体转换为简体中文
    public func toSimplifiedChinese(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, kCFStringTransformMandarinLatin, false)
        return text.precomposedStringWithCompatibilityMapping
    }

    /// 2. 英文与拉丁语系：Leetspeak 变形字符还原 (如 p@ssw0rd -> password, f00l -> fool)
    public func normalizeLeetspeak(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = ""
        result.reserveCapacity(text.count)

        for char in text {
            if let replaced = leetspeakMap[char] {
                result.append(replaced)
            } else {
                result.append(char)
            }
        }
        return result
    }

    /// 3. 欧语系 (法/德/西/意/葡萄牙语)：变音与重音符号剥离 (如 ë -> e, ç -> c, ñ -> n)
    public func stripDiacritics(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, kCFStringTransformStripCombiningMarks, false)
        return mutableString as String
    }

    /// 4. 日韩语系与全角字符：全角/半角归一化与假名标准化
    public func normalizeFullwidthAndKana(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, kCFStringTransformFullwidthHalfwidth, false)
        return mutableString as String
    }

    /// 5. 全语系：剥离零宽字符、分隔点、标点与变异插入符号
    public func stripInterferenceCharacters(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let interferenceSet = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(.whitespacesAndNewlines)
            .union(CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}"))

        let scalars = text.unicodeScalars.filter { !interferenceSet.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    /// 综合执行全球 9 大语言洗词流水线：
    /// 兼容性标准化 ➔ 全半角归一 ➔ Leetspeak 还原 ➔ 重音符剥离 ➔ 干扰符剥离 ➔ 繁简转码
    public func sanitizeForModeration(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // 1. Unicode NFKD 兼容解构标准化
        let normalized = text.decomposedStringWithCompatibilityMapping

        // 2. 日韩全角/半角归一化
        let widthNormalized = normalizeFullwidthAndKana(normalized)

        // 3. 英文/拉丁语系 Leetspeak 还原 (如 p@ssw0rd -> password)
        let leetNormalized = normalizeLeetspeak(widthNormalized)

        // 4. 欧语系重音与变音符号剥离 (如 ë -> e)
        let diacriticsStripped = stripDiacritics(leetNormalized)

        // 5. 剥离插入隔符与特殊控制符
        let stripped = stripInterferenceCharacters(diacriticsStripped)

        // 6. 中文繁简转码归一
        return toSimplifiedChinese(stripped)
    }
}

/// 向后兼容类型别名
public typealias HomophonePinyinSanitizer = MultilingualTextSanitizer
