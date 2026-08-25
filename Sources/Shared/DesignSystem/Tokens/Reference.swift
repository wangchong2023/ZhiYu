//
//  Reference.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 1 原子值层 — 严格有限的物理常量集，对齐 Tailwind CSS 默认 scale。
//           所有视觉值必须从这里取，禁止算术派生，禁止扩展。
//

import SwiftUI

/// Layer 1: 原子值层（Reference Tokens）
///
/// 严格有限的原子值集，对齐 Tailwind CSS 默认 spacing scale。
/// - 原子集严格有限，新增需设计审查
/// - 禁止算术派生
/// - 所有数值映射到原子集
public enum Reference {

    // MARK: - Spacing（17档，对齐 Tailwind 默认 scale）
    public enum Spacing {
        public static let zero: CGFloat = 0
        public static let half: CGFloat = 0.5      // hairline
        public static let one: CGFloat = 1          // divider
        public static let two: CGFloat = 2          // atomic
        public static let three: CGFloat = 3
        public static let four: CGFloat = 4          // tiny
        public static let five: CGFloat = 5          // extraSmall
        public static let six: CGFloat = 6
        public static let seven: CGFloat = 7          // smallMedium
        public static let eight: CGFloat = 8         // small
        public static let ten: CGFloat = 10           // elementLarge
        public static let twelve: CGFloat = 12       // medium
        public static let fourteen: CGFloat = 14      // contentMedium
        public static let sixteen: CGFloat = 16      // standard
        public static let twenty: CGFloat = 20        // section
        public static let twentyFour: CGFloat = 24    // sectionLarge
        public static let twentyEight: CGFloat = 28   // sectionCompact
        public static let thirtyTwo: CGFloat = 32     // huge
    }

    // MARK: - Opacity（13档）
    public enum Opacity {
        public static let zero: Double = 0
        public static let five: Double = 0.05        // ghost
        public static let ten: Double = 0.1          // faint
        public static let fifteen: Double = 0.15     // glass
        public static let twenty: Double = 0.2       // subtle
        public static let thirty: Double = 0.3       // light
        public static let forty: Double = 0.4        // medium
        public static let fifty: Double = 0.5        // soft
        public static let sixty: Double = 0.6        // dim
        public static let seventy: Double = 0.7      // translucent
        public static let eighty: Double = 0.8       // prominent
        public static let ninety: Double = 0.9       // strong
        public static let full: Double = 1.0         // solid
    }

    // MARK: - Radius（9档）
    public enum Radius {
        public static let zero: CGFloat = 0
        public static let two: CGFloat = 2           // micro
        public static let four: CGFloat = 4           // small
        public static let six: CGFloat = 6
        public static let eight: CGFloat = 8          // standard
        public static let twelve: CGFloat = 12        // large
        public static let sixteen: CGFloat = 16       // xl
        public static let twenty: CGFloat = 20        // 2xl
        public static let full: CGFloat = 9999        // capsule
    }

    // MARK: - Stroke（8档）
    public enum Stroke {
        public static let zero: CGFloat = 0
        public static let half: CGFloat = 0.5         // hairline
        public static let thin: CGFloat = 0.8         // border
        public static let one: CGFloat = 1            // divider
        public static let oneHalf: CGFloat = 1.5      // emphasis
        public static let two: CGFloat = 2            // selected
        public static let three: CGFloat = 3          // accent
        public static let four: CGFloat = 4           // heavy
    }

    // MARK: - FontSize（15档）
    public enum FontSize {
        public static let nano: CGFloat = 8          // xxs
        public static let micro: CGFloat = 10         // xs
        public static let microLarge: CGFloat = 11    // xs+
        public static let caption: CGFloat = 12       // sm
        public static let footnote: CGFloat = 13
        public static let subheadline: CGFloat = 14   // base
        public static let body: CGFloat = 16          // lg
        public static let headline: CGFloat = 17
        public static let title3: CGFloat = 18        // xl
        public static let title2: CGFloat = 20        // 2xl
        public static let title: CGFloat = 24         // 3xl
        public static let largeTitle: CGFloat = 28
        public static let display: CGFloat = 32       // 4xl
        public static let hero: CGFloat = 40          // 5xl
        public static let mega: CGFloat = 48          // 6xl
    }
}
