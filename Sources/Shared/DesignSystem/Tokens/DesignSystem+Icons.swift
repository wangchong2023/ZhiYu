//
//  DesignSystem+Icons.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import CoreGraphics

extension DesignSystem {
    
    // MARK: - 3. 图标体系 (Iconography)
    public enum Icons {
        public static let tiny: CGFloat = Spacing.iconTiny
        public static let small: CGFloat = Spacing.iconSmall
        public static let medium: CGFloat = Spacing.iconMedium
        public static let large: CGFloat = Spacing.iconLarge
        public static let huge: CGFloat = Spacing.iconHuge
        public static let display: CGFloat = Spacing.iconDisplay
        
        // ── 系统图标符号 (来自 Typography.Icons) ──
        public static let trophy = Typography.Icons.trophy
        public static let tag = Typography.Icons.tag
        public static let tagFill = Typography.Icons.tagFill
        public static let hashtag = Typography.Icons.hashtag
        public static let link = Typography.Icons.link
        public static let sparkles = Typography.Icons.sparkles
        public static let sparkle = Typography.Icons.sparkles
        public static let quote = Typography.Icons.quoteOpening
        public static let scan = "qrcode.viewfinder"
        public static let voiceNote = Typography.Icons.micFill
        public static let more = Typography.Icons.more
        public static let edit = Typography.Icons.edit
        public static let pencilCircle = Typography.Icons.pencilCircle
        public static let delete = Typography.Icons.delete
        public static let pin = Typography.Icons.pin
        public static let pinFill = "star.fill"
        public static let folderBadgePlus = "folder.badge.plus"
        public static let folderFill = "folder.fill"
        
        // ── 通用状态图标 ──
        public static let unpin = Typography.Icons.unpin
        public static let history = Typography.Icons.history
        public static let refresh = Typography.Icons.refresh
        public static let reset = Typography.Icons.reset
        public static let plus = Typography.Icons.plus
        public static let plusCircle = Typography.Icons.plusCircle
        public static let lock = Typography.Icons.lock
        public static let lockOpen = Typography.Icons.lockOpen
        public static let logout = Typography.Icons.logout
        public static let info = Typography.Icons.info
        public static let check = Typography.Icons.check
        public static let checkCircle = Typography.Icons.checkCircle
        public static let emptyCircle = "circle"
        public static let errorCircle = Typography.Icons.errorCircle
        public static let timer = Typography.Icons.timer
        public static let warning = Typography.Icons.warning
        public static let star = Typography.Icons.star
        public static let dotSeparator = Typography.Icons.dotSeparator
        public static let bullet = Typography.Icons.bullet
        public static let undo = Typography.Icons.undo
        public static let copy = Typography.Icons.copy
        public static let seal = Typography.Icons.seal
        public static let eyeSlash = Typography.Icons.eyeSlash
        public static let eyeSlashOutline = Typography.Icons.eyeSlashOutline
        public static let eye = Typography.Icons.eye
        public static let faceid = Typography.Icons.faceid
        public static let archive = Typography.Icons.archive
        public static let box = Typography.Icons.box
        public static let docRichtext = Typography.Icons.docRichtext
        public static let docBadgePlus = Typography.Icons.docBadgePlus
        public static let pencilClipboard = Typography.Icons.pencilClipboard
        public static let tray = Typography.Icons.tray
        public static let clock = Typography.Icons.clock
        public static let stop = Typography.Icons.stop
        public static let stopFill = "stop.fill"
        public static let stopRequest = "stop.circle.fill"
        public static let send = Typography.Icons.send
        public static let sendRequest = "paperplane.fill"
        
        // ── 物理补充：通用状态与导航 SF Symbols ──
        public static let exclamationShieldFill = "exclamationmark.shield.fill"
        public static let arrowClockwise = "arrow.clockwise"
        public static let chevronUp = "chevron.up"
        public static let chevronDown = "chevron.down"
        public static let chevronRight = "chevron.right"
        public static let apple = Typography.Icons.apple
        public static let message = Typography.Icons.message
        public static let sidebarToggle = Typography.Icons.sidebarLeft
        public static let settings = Typography.Icons.gearshape
        public static let promptLibrary = "sparkles.rectangle.stack"
        public static let thinking = Typography.Icons.sparkles
        public static let library = "books.vertical.fill"
        public static let arrowRight = Typography.Icons.arrowRight
        public static let arrowLeft = Typography.Icons.arrowLeft
        public static let arrowUpRightSimple = Typography.Icons.arrowUpRightSimple
        public static let arrowUpRightSquare = Typography.Icons.arrowUpRightSquare
        public static let arrowUpRightCircle = Typography.Icons.arrowUpRightCircle
        public static let arrowDownDoc = Typography.Icons.arrowDownDoc
        public static let arrowDownCircle = Typography.Icons.arrowDownCircle
        public static let arrowBranch = Typography.Icons.arrowBranch
        public static let micFill = Typography.Icons.micFill
        public static let micSlashFill = Typography.Icons.micSlashFill
        public static let libraryCircle = "books.vertical.circle.fill"
        public static let booksVerticalFill = Typography.Icons.booksVerticalFill
        public static let stackFill = Typography.Icons.stackFill
        public static let sortUpDown = Typography.Icons.sortUpDown
        public static let gridOutline = Typography.Icons.gridOutline
        public static let xmarkCircle = Typography.Icons.xmarkCircle
        public static let lockShieldFill = Typography.Icons.lockShieldFill
        public static let shieldFill = Typography.Icons.shieldFill
        public static let shieldSlash = Typography.Icons.shieldSlash
        public static let puzzlepieceExtension = Typography.Icons.puzzlepieceExtension
        public static let pluginOutline = Typography.Icons.pluginOutline
        public static let storefront = Typography.Icons.storefront
        public static let brain = Typography.Icons.brain
        public static let keyFill = Typography.Icons.keyFill
        public static let trayFill = Typography.Icons.trayFill
        public static let scope = Typography.Icons.scope
        public static let plusMagnifyingglass = Typography.Icons.plusMagnifyingglass
        public static let minusMagnifyingglass = Typography.Icons.minusMagnifyingglass
        public static let viewfinder = Typography.Icons.viewfinder
        public static let view3d = Typography.Icons.view3d
        public static let fullscreenEnter = Typography.Icons.fullscreenEnter
        public static let fullscreenExit = Typography.Icons.fullscreenExit
        public static let refreshCircle = Typography.Icons.refreshCircle
        public static let refreshCircleFill = Typography.Icons.refreshCircleFill
        public static let chartBarXaxis = Typography.Icons.chartBarXaxis
        public static let arrowTriangleBranch = Typography.Icons.arrowTriangleBranch
        public static let cellularbars = Typography.Icons.cellularbars
        public static let flag = Typography.Icons.flag
        public static let docOnClipboardFill = Typography.Icons.docOnClipboardFill
        public static let boltShieldFill = Typography.Icons.boltShieldFill
        public static let loop = Typography.Icons.arrowTriangle2Circlepath
        public static let exclamationCircleFill = Typography.Icons.exclamationmarkCircleFill
        public static let circle = Typography.Icons.circle
        public static let emptySquare = Typography.Icons.square
        public static let checkSquareFill = Typography.Icons.checkSquareFill
        public static let safari = Typography.Icons.safari
        public static let visionpro = Typography.Icons.visionpro
        public static let cubeTransparent = Typography.Icons.cubeTransparentFill
        public static let handTap = Typography.Icons.handTapFill
        public static let eyeFill = Typography.Icons.eyeFill
        public static let personCropPlus = Typography.Icons.personCropCircleBadgePlus
        public static let filterCircle = Typography.Icons.filterCircle
        public static let line3Horizontal = Typography.Icons.line3Horizontal
        public static let waveform = Typography.Icons.waveform
        public static let waveformCircleFill = Typography.Icons.waveformCircleFill
        public static let documentFill = Typography.Icons.documentFill
        public static let document = Typography.Icons.document
        public static let photoOnRectangle = Typography.Icons.photoOnRectangle
        public static let highlighterFill = Typography.Icons.highlighterFill
        public static let starSquareFill = Typography.Icons.starSquareFill
        public static let docOnClipboard = Typography.Icons.docOnClipboard
        public static let listBulletRectangle = Typography.Icons.listBulletRectangle
        public static let listBulletRectanglePortrait = Typography.Icons.listBulletRectanglePortrait
        public static let trashSlashOutline = Typography.Icons.trashSlashOutline
        public static let trashSlash = Typography.Icons.trashSlash
        public static let pencilLine = Typography.Icons.pencilLine
        public static let pencilOutline = Typography.Icons.pencilOutline
        public static let squareAndPencil = Typography.Icons.squareAndPencil
        public static let quoteOpening = Typography.Icons.quoteOpening
        public static let quoteClosing = Typography.Icons.quoteClosing
        public static let docOnDocFill = Typography.Icons.docOnDocFill
        public static let circleGrid3x3Fill = Typography.Icons.circleGrid3x3Fill
        public static let hexagonGridFill = Typography.Icons.hexagonGridFill

        public static let quoteBubble = Typography.Icons.quoteBubbleFill
        public static let bold = Typography.Icons.bold
        public static let italic = Typography.Icons.italic
        public static let xmark = Typography.Icons.xmark
        public static let personCrop = Typography.Icons.personCropCircle
        public static let personCropFill = Typography.Icons.personCropCircleFill
        public static let back = Typography.Icons.back
        public static let backToHub = Typography.Icons.backCircle
        public static let forward = Typography.Icons.forward
        public static let forwardCircle = Typography.Icons.forwardCircle
        public static let arrowUpRight = Typography.Icons.arrowUpRight
        public static let search = Typography.Icons.search
        public static let command = Typography.Icons.command
        public static let checklist = Typography.Icons.checklist
        public static let up = Typography.Icons.chevronUp
        public static let down = Typography.Icons.chevronDown
        public static let grid = Typography.Icons.grid
        public static let list = Typography.Icons.list
        public static let chevronUpDown = Typography.Icons.chevronUpDown
        
        // ── 硬件与系统 ──
        public static let person = Typography.Icons.person
        public static let personCircle = Typography.Icons.personCircle
        public static let personCheck = Typography.Icons.personCheck
        public static let persons = Typography.Icons.persons
        public static let personsCircle = Typography.Icons.personsCircle
        public static let cpu = Typography.Icons.cpu
        public static let cpuOutline = Typography.Icons.cpuOutline
        public static let bolt = Typography.Icons.bolt
        public static let antenna = Typography.Icons.antenna

        // ── 端侧模型图标 (On-Device Model Icons) ──
        /// 内置模型图标
        public static let onDeviceBundled = "cube.box.fill"
        /// 已下载模型图标
        public static let onDeviceDownloaded = "arrow.down.circle.fill"
        /// 系统模型图标
        public static let onDeviceSystem = "apple.logo"
        
        // ── 业务/特性专用 ──
        public static let knowledge = Typography.Icons.knowledge
        public static let dashboard = Typography.Icons.dashboard
        public static let pageList = Typography.Icons.pageList
        public static let weeklyInsight = Typography.Icons.weeklyInsight
        public static let healthCheck = Typography.Icons.healthCheck
        public static let plugins = Typography.Icons.plugins
        public static let collaboration = Typography.Icons.collaboration
        public static let collaborationPeers = Typography.Icons.persons // 兼容别名
        public static let broadcast = Typography.Icons.antenna // 兼容别名
        public static let crown = Typography.Icons.crown
        public static let synthesisIcon = Typography.Icons.synthesisIcon
        public static let chatBubble = Typography.Icons.chatBubble
        public static let trayArrowDown = Typography.Icons.trayArrowDown
        public static let importIcon = Typography.Icons.trayArrowDown // 兼容别名
        public static let export = "square.and.arrow.up" // 兼容别名
        public static let ocr = Typography.Icons.ocr
        public static let mic = Typography.Icons.mic
        
        // ── 统计与图表 ──
        public static let chartLine = Typography.Icons.chartLine
        public static let chartPie = Typography.Icons.chartPie
        public static let chartBar = Typography.Icons.chartBar
        public static let network = Typography.Icons.network
        public static let database = Typography.Icons.database
        public static let log = Typography.Icons.log
        
        // ── 知识分类语义化图标 ──
        public static let entity = Typography.Icons.entity
        public static let concept = Typography.Icons.concept
        public static let source = Typography.Icons.source
        public static let comparison = Typography.Icons.comparison
        public static let map = Typography.Icons.map
        public static let raw = Typography.Icons.raw
        
        // ── 扩展映射 ──
        public static let photoAlbum = Typography.Icons.photoAlbum
        public static let highlighter = Typography.Icons.highlighter
        public static let wand = Typography.Icons.wand
        public static let aiSummary = Typography.Icons.wand
        public static let aiExtract = Typography.Icons.sealCheck
        public static let mindmap = Typography.Icons.mindmap
        public static let quiz = Typography.Icons.questionCircle
        public static let questionCircle = Typography.Icons.questionCircle
        public static let slides = Typography.Icons.playRectangle
        public static let report = Typography.Icons.weeklyInsight
        public static let infographic = Typography.Icons.chartBarDoc
        public static let lab = Typography.Icons.flask
        public static let expandStub = Typography.Icons.textBadgePlus
        public static let findLinks = Typography.Icons.linkBadgePlus
        public static let sortName = Typography.Icons.sortName
        public static let sortDate = Typography.Icons.calendar
        public static let wordCount = Typography.Icons.textformat
        public static let pushToCloud = Typography.Icons.icloudArrowUp
        public static let pullFromCloud = Typography.Icons.pullFromCloud
        public static let bidirectionalSync = Typography.Icons.icloudSync
        public static let clearCloudData = Typography.Icons.trashICloud
        public static let rebuildInitialNotebooks = Typography.Icons.testtube
        public static let stressTest = Typography.Icons.gauge100
        public static let llmConfig = Typography.Icons.sliderHorizontal
        public static let theme = Typography.Icons.paintbrush
        public static let language = Typography.Icons.globe
        public static let llmSettings = Typography.Icons.brainProfile
        public static let promptLab = Typography.Icons.terminal
        public static let iCloudSync = Typography.Icons.icloud
        public static let operationLog = Typography.Icons.listBulletRectangle
        public static let privacyMode = Typography.Icons.eyeSlash
        public static let developer = Typography.Icons.hammer
        public static let promptWorkshop = Typography.Icons.flaskFill
        public static let macwindowBadgePlus = Typography.Icons.macwindowBadgePlus
        public static let photo = Typography.Icons.photo
        public static let externaldrive = Typography.Icons.externaldrive
        
        // ── 未归类补充 ──
        /// 孤立页面图标 (用于 Lint 孤儿节点)
        public static let orphanPage = "person.fill.questionmark"
        /// 合并操作图标
        public static let merge = "arrow.merge"
        /// 分支操作图标
        public static let branch = "arrow.branch"
        /// 重命名/光标图标
        public static let cursorIbeam = "character.cursor.ibeam"
        /// 空白虚线框 (OnDevice 下载前占位)
        public static let squareDashed = "square.dashed"
        /// 文字气泡
        public static let textBubble = "text.bubble.fill"
        /// 柱状图统计
        public static let chartBarFill = "chart.bar.fill"
        /// 叶子填充
        public static let leafFill = "leaf.fill"
        /// 水滴填充
        public static let dropFill = "drop.fill"
        /// 纸飞机填充
        public static let paperplaneFill = "paperplane.fill"
        /// 勾选圆圈填充
        public static let checkmarkCircleFill = "checkmark.circle.fill"
        /// iPhone 无线电波
        public static let iphoneRadiowaves = "iphone.radiowaves.left.and.right"
        /// 放大镜（与 search 同义，显式命名以匹配 SF Symbol 原名）
        public static let magnifyingglass = "magnifyingglass"
        /// CPU（非填充，对应 SF Symbol "cpu"）
        public static let cpuSymbol = "cpu"
        /// 网络节点（对应 SF Symbol "network"，区别于 network 统计图标）
        public static let networkSymbol = "network"
        /// 归档箱填充（显式命名以匹配 SF Symbol 原名）
        public static let archiveboxFill = "archivebox.fill"
        
        // ── 设置中心专属分类 SF Symbol 图标收口 ──
        /// 外观设置图标
        public static let settingsAppearance = "paintbrush.fill"
        /// AI 核心设置图标
        public static let settingsAI = "network"
        /// 安全隐私设置图标
        public static let settingsSecurity = "eye.slash.fill"
        /// 数据备份与管理图标
        public static let settingsData = "archivebox.fill"
        /// 插件市场与管理图标
        public static let settingsPlugins = "puzzlepiece.fill"
        /// 开发者诊断工具图标
        public static let settingsDeveloper = "hammer.fill"
        /// 关于软件说明图标
        public static let settingsAbout = "info.circle"

        // MARK: - 笔记本 Emoji

        public enum Notebook {
            /// 默认笔记本图标
            public static let defaultBook: String = "📚"
            /// 项目调研笔记本图标
            public static let defaultResearch: String = "🔬"
            /// 兜底笔记本图标
            public static let fallback: String = "📓"
            /// 可选图标列表
            public static let options: [String] = [
                "📚", "🔬", "📓", "📖", "📝", "🗂️", "📊", "🧪",
                "💡", "🎯", "🚀", "⭐", "🔧", "🎨", "📐", "💭"
            ]
        }

        /// 存储统计分类图标
        public enum StorageStats {
            /// 数据库
            public static let database = "cylinder.split.1x2.fill"
            /// 日志
            public static let logs = "doc.text.below.ecg.fill"
            /// 导入
            public static let storageImport = "books.vertical.fill"
            /// 导出
            public static let storageExport = "square.and.arrow.up.fill"
            /// 模型
            public static let models = "cpu.fill"
            /// 插件
            public static let plugins = "puzzlepiece.fill"
            /// 缓存
            public static let caches = "trash.circle.fill"
            /// 兜底
            public static let fallback = "folder.fill"
        }

        // MARK: - Features 层补充图标 (Phase 2 magic_string 整改)
        /// 归档箱（非填充）
        public static let archiveboxOutline = "archivebox"
        /// 逆时针箭头
        public static let arrowCounterclockwise = "arrow.counterclockwise"
        /// 合并箭头
        public static let arrowTriangleMerge = "arrow.triangle.merge"
        /// 上箭头
        public static let arrowUp = "arrow.up"
        /// 右上气泡箭头
        public static let arrowUpRightBubble = "arrow.up.right.bubble"
        /// 左转 U 型箭头
        public static let arrowUturnLeft = "arrow.uturn.left"
        /// 闪电填充
        public static let boltFill = "bolt.fill"
        /// 双气泡对话
        public static let bubbleLeftAndRight = "bubble.left.and.bubble.right"
        /// 相机取景器
        public static let cameraViewfinder = "camera.viewfinder"
        /// iCloud 勾选填充
        public static let checkmarkIcloudFill = "checkmark.icloud.fill"
        /// 勾选盾牌
        public static let checkmarkShield = "checkmark.shield"
        /// 勾选盾牌填充
        public static let checkmarkShieldFill = "checkmark.shield.fill"
        /// 左圆圈右箭头填充
        public static let chevronLeftCircleFill = "chevron.left.circle.fill"
        /// 右圆圈右箭头填充
        public static let chevronRightCircleFill = "chevron.right.circle.fill"
        /// 文档（非填充）
        public static let doc = "doc"
        /// 纯文本文档
        public static let docPlaintext = "doc.plaintext"
        /// 心电图文档
        public static let docTextBelowEcg = "doc.text.below.ecg"
        /// 美元符号圆圈
        public static let dollarsignCircle = "dollarsign.circle"
        /// 八角形感叹号填充
        public static let exclamationmarkOctagonFill = "exclamationmark.octagon.fill"
        /// 方格旗
        public static let flagCheckered = "flag.checkered"
        /// 仪表盘（非填充）
        public static let gaugeWithNeedle = "gauge.with.needle"
        /// 双齿轮
        public static let gearshape2 = "gearshape.2"
        /// 后退 5 秒
        public static let goBackward5 = "gobackward.5"
        /// 前进 5 秒
        public static let goForward5 = "goforward.5"
        /// 点赞填充
        public static let handThumbsupFill = "hand.thumbsup.fill"
        /// 信息圆圈填充
        public static let infoCircleFill = "info.circle.fill"
        /// 灯泡
        public static let lightbulb = "lightbulb"
        /// 列表带剪贴板
        public static let listBulletClipboard = "list.bullet.clipboard"
        /// 列表缩进
        public static let listBulletIndent = "list.bullet.indent"
        /// 编号列表
        public static let listNumber = "list.number"
        /// 数字圆圈
        public static let numberCircle = "number.circle"
        /// 暂停填充
        public static let pauseFill = "pause.fill"
        /// 人物徽章钥匙填充
        public static let personBadgeKeyFill = "person.badge.key.fill"
        /// 电话填充
        public static let phoneFill = "phone.fill"
        /// 播放填充
        public static let playFill = "play.fill"
        /// 播放矩形填充
        public static let playRectangleFill = "play.rectangle.fill"
        /// 加号取景器
        public static let plusViewfinder = "plus.viewfinder"
        /// 拼图块扩展填充
        public static let puzzlepieceExtensionFill = "puzzlepiece.extension.fill"
        /// 问号圆圈填充
        public static let questionmarkCircleFill = "questionmark.circle.fill"
        /// 服务器机架
        public static let serverRack = "server.rack"
        /// 方框向下箭头（下载）
        public static let squareAndArrowDown = "square.and.arrow.down"
        /// 方框填充
        public static let squareFill = "square.fill"
        /// WiFi
        public static let wifi = "wifi"

        // MARK: - Typography.Icons 转发 (Phase 2 magic_string 整改补充)
        /// 烧瓶填充
        public static let flaskFill = Typography.Icons.flaskFill
        /// 感叹号圆圈填充
        public static let exclamationmarkCircleFill = Typography.Icons.exclamationmarkCircleFill
        /// iCloud 下载箭头
        public static let icloudArrowDown = Typography.Icons.icloudArrowDown
        /// 水平滑块
        public static let sliderHorizontal = Typography.Icons.sliderHorizontal
        /// 地球
        public static let globe = Typography.Icons.globe
        /// 列表带矩形填充
        public static let listBulletRectangleFill = Typography.Icons.listBulletRectangleFill
        /// 日历
        public static let calendar = Typography.Icons.calendar
        /// 柱状图文档
        public static let chartBarDoc = Typography.Icons.chartBarDoc
        /// 链接徽章加号
        public static let linkBadgePlus = Typography.Icons.linkBadgePlus
        /// 模型/CPU（用于路由偏好等场景）
        public static let models = Typography.Icons.cpu
        /// 任务图标
        public static let chatBubbles = "bubble.left.and.bubble.right.fill"
        public static let checklistChecked = "checklist.checked"
        public static let chevronCode = "chevron.left.forwardslash.chevron.right"
        public static let docMagnify = "doc.text.magnifyingglass"
        public static let characterBook = "character.book.closed.fill"
        /// 大脑轮廓（AI/推理）
        public static let brainProfile = Typography.Icons.brainProfile
        /// 文档图标
        public static let docText = "doc.text"
        public static let docTextFill = "doc.text.fill"
        /// 日历时间线
        public static let calendarDayTimeline = "calendar.day.timeline.left"
        /// Apple/Google/GitHub Logo
        public static let appleLogo = "apple.logo"
        public static let applelogo = "applelogo"
        public static let googleLogo = "GoogleLogo"
        public static let githubLogo = "GithubLogo"
        /// WiFi 断开
        public static let wifiSlash = "wifi.slash"
        /// 内存芯片
        public static let memorychipFill = "memorychip.fill"
        /// 数字/人员/应用徽章/勾选印章
        public static let number = "number"
        public static let personFill = "person.fill"
        public static let appBadgeCheckmark = "app.badge.checkmark"
        public static let checkmarkSealFill = "checkmark.seal.fill"
        /// 感叹号气泡
        public static let exclamationmarkBubble = "exclamationmark.bubble"
        /// 听诊器
        public static let stethoscope = "stethoscope"
        /// 文档取景器（OCR）
        public static let docTextViewfinder = "doc.text.viewfinder"
        /// 目标靶心
        public static let target = "target"
        /// 收件箱箭头（入库）
        public static let trayArrowDownFill = "tray.and.arrow.down.fill"
        /// 魔法星星（合成）
        public static let wandAndStars = "wand.and.stars"
    }
}
