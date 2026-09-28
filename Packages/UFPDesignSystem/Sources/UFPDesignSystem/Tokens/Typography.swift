//
//  Typography.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：排版令牌：字号分级、标题等级枚举及常用系统图标映射。
//           所有字体使用 Dynamic Type 语义样式，支持辅助功能字号自动缩放。
//
import SwiftUI

extension DesignTokens {
    /// 智宇排版令牌 (Typography Tokens)
    /// 包含字号分级、标题等级枚举及常用系统图标映射。
    public enum Typography {

        // MARK: - 1. 标题等级 (Heading Levels)
        // MARK: @PR-03: 层次化排版规范，优化文本渲染开销

        /// 标题等级枚举
        /// 字号使用 Dynamic Type 语义样式，确保随用户辅助功能字号设置自动缩放
        public enum HeadingLevel: Int {
            case h1 = 1, h2, h3, h4, h5, h6

            /// 参考字号（仅用于布局计算，不直接用于字体渲染）
            public var size: CGFloat {
                switch self {
                case .h1: return 28
                case .h2: return 22
                case .h3: return 20
                case .h4: return 18
                case .h5: return 16
                case .h6: return 14
                }
            }

            /// Dynamic Type 字体映射
            /// 遵循 HIG: 使用语义化样式以支持辅助功能字号缩放
            public var font: Font {
                switch self {
                case .h1: return .title.bold()
                case .h2: return .title2.bold()
                case .h3: return .title3.bold()
                case .h4: return .headline
                case .h5: return .subheadline.weight(.semibold)
                case .h6: return .footnote.weight(.medium)
                }
            }

            /// 字重映射（用于自定义渲染场景）
            public var weight: Font.Weight {
                switch self {
                case .h1, .h2, .h3: return .bold
                case .h4, .h5: return .semibold
                case .h6: return .medium
                }
            }

            /// 标题顶部间距规范
            public var topPadding: CGFloat {
                switch self {
                case .h1: return 24
                case .h2: return 20
                case .h3: return 16
                case .h4: return 12
                case .h5, .h6: return 8
                }
            }
        }

        // MARK: - 2. 原子字号 (Atomic Font Sizes)

        /// 微型字号 (11pt) — 对齐 HIG 最小可读字号（Caption 2 基准）
        public static let microFontSize: CGFloat = 11
        /// 脚注字号 (12px)
        public static let captionFontSize: CGFloat = 12
        /// 次级脚注字号 (11px)
        public static let caption2FontSize: CGFloat = 11
        /// 副标题字号 (14px)
        public static let subheadlineFontSize: CGFloat = 14
        /// 正文字号 (16px)
        public static let bodyFontSize: CGFloat = 16
        /// 标准字号 (16px)
        public static let standardFontSize: CGFloat = 16
        /// 标题字号 (18px)
        public static let headlineFontSize: CGFloat = 18
        /// 大标题字号 (24px)
        public static let titleFontSize: CGFloat = 24
        /// 展示大字号 (32px)
        public static let displayFontSize: CGFloat = 32

        // MARK: - 3. 字体快捷访问 (Font Shortcuts)
        // 遵循 HIG：使用 Dynamic Type 语义样式，支持辅助功能字号自动缩放

        /// 标准脚注字体（Dynamic Type: .caption）
        public static var captionFont: Font { .caption }
        /// 次级脚注字体（Dynamic Type: .caption2 Medium）
        public static var caption2Font: Font { .caption2.weight(.medium) }
        /// 标准二级辅助字体（Dynamic Type: .subheadline）
        public static var secondaryFont: Font { .subheadline }
        /// 标准大标题粗体（Dynamic Type: .title2 Bold）
        public static var titleFont: Font { .title2.bold() }

        // MARK: - 4. 系统图标映射 (Icons)

        /// 定义应用中常用的系统图标 (SF Symbols) 映射
        public struct Icons {
            // ── 语音图标 ──
            public static let micFill = "mic.fill"
            public static let micSlashFill = "mic.slash.fill"
            public static let star = "star.fill"
            public static let eye = "eye"
            public static let pencilClipboard = "pencil.and.list.clipboard"

            // ── 基础状态图标 ──
            public static let trophy = "trophy.fill"
            public static let tag = "tag"
            public static let tagFill = "tag.fill"
            public static let hashtag = "number"
            public static let link = "link"
            public static let sparkles = "sparkles"
            public static let more = "ellipsis.circle"
            public static let edit = "pencil"
            public static let pencilCircle = "pencil.circle.fill"
            public static let delete = "trash"
            public static let pin = "star"
            public static let unpin = "star.slash"
            public static let history = "clock.arrow.circlepath"
            public static let refresh = "arrow.clockwise"
            public static let reset = "arrow.triangle.2.circlepath"
            public static let plus = "plus"
            public static let plusCircle = "plus.circle.fill"
            public static let lock = "lock.fill"
            public static let lockOpen = "lock.open.fill"
            public static let logout = "rectangle.portrait.and.arrow.right"
            public static let info = "info.circle"
            public static let check = "checkmark"
            public static let checkCircle = "checkmark.circle.fill"
            public static let errorCircle = "xmark.circle.fill"
            public static let timer = "timer"
            public static let warning = "exclamationmark.triangle.fill"
            public static let dotSeparator = ""
            public static let bullet = ""
            public static let undo = "arrow.uturn.backward"
            public static let copy = "doc.on.doc"
            public static let seal = "checkmark.seal.fill"
            public static let eyeSlash = "eye.slash.fill"
            public static let eyeSlashOutline = "eye.slash"
            public static let faceid = "faceid"
            public static let archive = "archivebox.fill"
            public static let box = "cube.box"
            public static let docRichtext = "doc.richtext.fill"
            public static let docBadgePlus = "doc.badge.plus"
            public static let tray = "tray"
            public static let clock = "clock"
            public static let stop = "stop.circle.fill"
            public static let send = "arrow.up.circle.fill"
            public static let apple = "apple.logo"
            public static let message = "message.fill"

            // ── 导航与 UI 图标 ──
            public static let back = "chevron.left"
            public static let backCircle = "arrow.left.circle.fill"
            public static let forward = "chevron.right"
            public static let forwardCircle = "arrow.right.circle.fill"
            public static let arrowUpRight = "arrow.up.right.circle.fill"
            public static let arrowDownCircle = "arrow.down.circle"
            public static let search = "magnifyingglass"
            public static let command = "command"
            public static let checklist = "checklist"
            public static let grid = "rectangle.grid.2x2.fill"
            public static let list = "list.bullet"
            public static let chevronUpDown = "chevron.up.chevron.down"
            public static let chevronUp = "chevron.up"
            public static let chevronDown = "chevron.down"
            public static let line3Horizontal = "line.3.horizontal"
            public static let filterCircle = "line.3.horizontal.decrease.circle"

            // ── 硬件与系统 ──
            public static let person = "person.fill"
            public static let personCircle = "person.circle.fill"
            public static let personCheck = "person.fill.checkmark"
            public static let persons = "person.2.fill"
            public static let personsCircle = "person.2.circle.fill"
            public static let cpu = "cpu.fill"
            public static let cpuOutline = "cpu"
            public static let bolt = "bolt.horizontal.fill"
            public static let antenna = "antenna.radiowaves.left.and.right"
            public static let safari = "safari"
            public static let visionpro = "visionpro"
            public static let shieldFill = "shield.fill"
            public static let shieldSlash = "shield.slash"
            public static let brain = "brain"
            public static let keyFill = "key.fill"

            // ── 业务/特性专用 ──
            public static let knowledge = "books.vertical.circle.fill"
            public static let dashboard = "gauge.with.needle.fill"
            public static let pageList = "tray.full.fill"
            public static let weeklyInsight = "doc.text.magnifyingglass"
            public static let healthCheck = "stethoscope"
            public static let plugins = "puzzlepiece.fill"
            public static let pluginOutline = "puzzlepiece"
            public static let storefront = "storefront"
            public static let collaboration = "bubble.left.and.bubble.right.fill"
            public static let crown = "crown.fill"
            public static let synthesisIcon = "sparkles.rectangle.stack"
            public static let chatBubble = "text.bubble.fill"
            public static let trayArrowDown = "tray.and.arrow.down.fill"
            public static let ocr = "text.viewfinder"
            public static let mic = "mic.fill"
            public static let waveform = "waveform"
            public static let waveformCircleFill = "waveform.circle.fill"

            // ── 统计与图表 ──
            public static let chartLine = "chart.line.uptrend.xyaxis"
            public static let chartPie = "chart.pie"
            public static let chartBar = "chart.bar.fill"
            public static let network = "point.3.connected.trianglepath.dotted"
            public static let database = "cylinder.split.1x2.fill"
            public static let log = "doc.text.below.ecg.fill"

            // ── 知识分类语义化图标 ──
            public static let entity = "person.text.rectangle.fill"
            public static let concept = "lightbulb.fill"
            public static let source = "doc.richtext.fill"
            public static let comparison = "arrow.left.and.right.righttriangle.left.righttriangle.right.fill"
            public static let map = "map.fill"
            public static let raw = "doc.plaintext.fill"

            // ── 额外系统图标 ──
            public static let trashSlash = "trash.slash.fill"
            public static let trashSlashOutline = "trash.slash"
            public static let document = "doc.text"
            public static let photoOnRectangle = "photo.on.rectangle"
            public static let documentFill = "doc.text.fill"
            public static let photoAlbum = "photo.on.rectangle"
            public static let highlighter = "highlighter"
            public static let highlighterFill = "highlighter.fill"
            public static let wand = "wand.and.stars"
            public static let sealCheck = "checkmark.seal"
            public static let mindmap = "rectangle.stack.badge.person.crop"
            public static let questionCircle = "questionmark.circle"
            public static let playRectangle = "play.rectangle"
            public static let chartBarDoc = "chart.bar.doc.horizontal"
            public static let flask = "flask"
            public static let textBadgePlus = "text.badge.plus"
            public static let linkBadgePlus = "link.badge.plus"
            public static let sortName = "abc"
            public static let calendar = "calendar"
            public static let textformat = "textformat"
            public static let icloudArrowUp = "icloud.and.arrow.up"
            public static let icloudArrowDown = "icloud.and.arrow.down"
            public static let pullFromCloud = "icloud.and.arrow.down"
            public static let icloudSync = "arrow.triangle.2.circlepath.icloud"
            public static let trashICloud = "trash.icloud"
            public static let testtube = "testtube.2"
            public static let gauge100 = "gauge.with.dots.needle.bottom.100percent"
            public static let sliderHorizontal = "slider.horizontal.3"
            public static let paintbrush = "paintbrush.fill"
            public static let globe = "globe"
            public static let brainProfile = "brain.head.profile"
            public static let terminal = "terminal.fill"
            public static let icloud = "icloud.fill"
            public static let listBulletRectangle = "list.bullet.rectangle"
            public static let listBulletRectangleFill = "list.bullet.rectangle.fill"
            public static let listBulletRectanglePortrait = "list.bullet.rectangle.portrait"
            public static let hammer = "hammer.fill"
            public static let flaskFill = "flask.fill"
            public static let sidebarLeft = "sidebar.left"
            public static let gearshape = "gearshape"
            public static let macwindowBadgePlus = "macwindow.badge.plus"
            public static let photo = "photo"
            public static let externaldrive = "externaldrive"
            public static let starSquareFill = "star.square.fill"
            public static let docOnClipboard = "doc.on.clipboard"

            // ── 箭头与指向 ──
            public static let arrowRight = "arrow.right"
            public static let arrowLeft = "arrow.left"
            public static let arrowUpRightSimple = "arrow.up.right"
            public static let arrowUpRightSquare = "arrow.up.right.square"
            public static let arrowUpRightCircle = "arrow.up.right.circle"
            public static let arrowDownDoc = "arrow.down.doc"
            public static let arrowBranch = "arrow.branch"
            public static let sortUpDown = "arrow.up.arrow.down"

            // ── 编辑与创作 ──
            public static let pencilLine = "pencil.line"
            public static let pencilOutline = "pencil.and.outline"
            public static let squareAndPencil = "square.and.pencil"
            public static let squareAndArrowUp = "square.and.arrow.up"
            public static let quoteOpening = "quote.opening"
            public static let quoteClosing = "quote.closing"
            public static let docOnDocFill = "doc.on.doc.fill"
            public static let quoteBubbleFill = "quote.bubble.fill"
            public static let bold = "bold"
            public static let italic = "italic"
            public static let xmark = "xmark"
            public static let personCropCircle = "person.crop.circle"
            public static let personCropCircleFill = "person.crop.circle.fill"

            // ── 容器与视图 ──
            public static let circleGrid3x3Fill = "circle.grid.3x3.fill"
            public static let hexagonGridFill = "circle.hexagongrid.fill"
            public static let gridOutline = "square.grid.2x2"
            public static let xmarkCircle = "xmark.circle"
            public static let lockShieldFill = "lock.shield.fill"
            public static let puzzlepieceExtension = "puzzlepiece.extension"
            public static let trayFill = "tray.fill"
            public static let booksVerticalFill = "books.vertical.fill"
            public static let stackFill = "square.stack.3d.up.fill"

            // ── 探测与缩放 ──
            public static let scope = "scope"
            public static let plusMagnifyingglass = "plus.magnifyingglass"
            public static let minusMagnifyingglass = "minus.magnifyingglass"
            public static let viewfinder = "viewfinder"
            public static let view3d = "view.3d"
            public static let cellularbars = "cellularbars"
            public static let flag = "flag"
            public static let fullscreenEnter = "arrow.up.left.and.arrow.down.right"
            public static let fullscreenExit = "arrow.down.right.and.arrow.up.left"
            public static let refreshCircle = "arrow.clockwise.circle"
            public static let refreshCircleFill = "arrow.clockwise.circle.fill"
            public static let chartBarXaxis = "chart.bar.xaxis"
            public static let arrowTriangleBranch = "arrow.triangle.branch"
            public static let infoCircle = "info.circle"
            public static let docOnClipboardFill = "doc.on.clipboard.fill"
            public static let boltShieldFill = "bolt.shield.fill"
            public static let arrowTriangle2Circlepath = "arrow.triangle.2.circlepath"
            public static let exclamationmarkCircleFill = "exclamationmark.circle.fill"
            public static let circle = "circle"
            public static let square = "square"
            public static let checkSquareFill = "checkmark.square.fill"
            public static let cubeTransparentFill = "cube.transparent.fill"
            public static let handTapFill = "hand.tap.fill"
            public static let eyeFill = "eye.fill"
            public static let personCropCircleBadgePlus = "person.crop.circle.badge.plus"
        }
    }
}
