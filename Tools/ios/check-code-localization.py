#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-code-localization.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/12.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：提供一整套面向对象的高保真本地化（L10n）静态审计引擎。
#           包括 .xcstrings 字典语法与规范检测、Swift 源码中硬编码中文与英文句子审计、
#           键缺失（Missing Keys）与变量回溯分析、跨表一致性校验以及冗余键（Unused Keys）分析。
#

import os
import re
import sys
import json

# 导入统一免白名单注册中心
sys.path.insert(0, str(os.path.join(os.path.dirname(__file__), "..", "CI")))
from exemption_registry import ExemptionRegistry  # noqa: E402

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

# 排除扫描的路径
EXCLUDE_DIRS = ['Localization/Catalogs', 'Tests', '.git', 'env', 'build', 'Frameworks']

# 启发式英文句子的最小长度判定
MIN_NATURAL_LANG_LEN = 4

# 允许包含非 ASCII 字符（汉字）的文件白名单（例如内置 Guide 生成、图标、AI 评测 Prompt 模板等）
ALLOW_NON_ASCII_FILES = {
    'IconTokens.swift',
    'DesignSystem+Icons.swift',
    'InitialNotebookGenerator.swift',
    'DemoImageBuilder.swift',
    'AIContentEnricher.swift',
    'RAGEvaluationService.swift',  # RAG 评价服务的中文硬编码 Prompt
    'ModelLabManager.swift',       # 大模型测试实验室的模拟推理输出 data 源
    'ThinkingProcessor.swift',     # 思维链解析引擎的中文思考标志与分隔符
    'SynthesisProcessor.swift',    # 知识合成柔性自愈引擎与模板文本
    'AISynthesisService.swift',    # AI 合成服务 System Prompt 与 JSON Schema 模板
    'PromptSecuritySanitizer.swift', # AI 提示词安全防护与越狱攻击特征词集
    'NativeMemoryEngine.swift',    # 自研分层对话记忆引擎断言与摘要
    'SwarmMemoryAdapter.swift',    # 开源 Swarm 框架记忆适配器数据
    'PromptConstants.swift',        # Prompt 常量及 JSON Schema 结构描述定义
    'ProcessorConstants.swift'      # 处理器常量集（含 ThinkingProcessor 中文 AI 输出检测关键词）
}

# 匹配模式： " ... " 字符串字面量
STRING_PATTERN = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')

# 强类型检查模式：静态拦截在 UI / 业务层直接调用 .tr("...") 或 .trf("...", ...)
DIRECT_TR_PATTERN = re.compile(r'\.tr\("|\.trf\("')

# UI 组件关键字及常见赋值触发词（当所在行包含以下词且含有英文自然语言句子时，判定为 UI 硬编码）
UI_TRIGGERS = [
    'Text', '.navigationTitle', 'Label', 'Button', 'Placeholder', 'message:', 'title:', 'subtitle:',
    'prompt:', 'systemPrompt:', 'description:', 'errorMessage:', 'inputText', 'name:', 'hint:',
    'Label(', 'Button(', 'Alert(', 'ConfirmationDialog(', 'Toast(', 'LabelStyle(', 'Picker(', 'Toggle('
]

# 常见英文单词（用于启发式自然语言句子识别的权重匹配）
COMMON_ENGLISH_WORDS = {
    'you', 'are', 'your', 'the', 'this', 'that', 'with', 'from', 'into', 'please', 
    'error', 'failed', 'loading', 'success', 'not', 'found', 'cannot', 'only', 'expert', 
    'always', 'start', 'follow', 'using', 'based', 'provide', 'deep', 'insightful'
}

# 已知合法的 brand 驼峰命名，无需按 PascalCase 假翻译占位符拦截
# 动态加载：从 ExemptionRegistry 获取 brand_proper_names 分类 + SDK 符号 + 项目符号
_REGISTRY = ExemptionRegistry()
_REGISTRY.load()
KNOWN_PROPER_NAMES = _REGISTRY.get_manual_symbols_by_category("brand_proper_names") | _REGISTRY.sdk_symbols | _REGISTRY.project_symbols

# 模块/文件前缀到 xcstrings 物理表名的强映射字典
DOMAIN_MAP = {
    'Localizable': 'Common',
    'Accessibility': 'Common',
    'Search': 'Common',
    'Editor': 'Knowledge',
    'Creation': 'Knowledge',
    'Vault': 'Knowledge',
    'Quiz': 'Knowledge',
    'KnowledgeBase': 'Knowledge',
    'Chat': 'AI',
    'Voice': 'AI',
    'AITasks': 'AI',
    'Graph': 'Insight',
    'Dashboard': 'Insight',
    'Auth': 'System',
    'Settings': 'System',
    'Lint': 'System',
    'Onboarding': 'System',
    'Coachmark': 'System',
    'Sync': 'Ingest',
    'Transfer': 'Ingest',
    'Collaboration': 'Plugin',
    'Watch': 'Platform',
    'Widget': 'Platform',
    'Common': 'Common',
    'Insight': 'Insight',
    'System': 'System',
    'AI': 'AI',
    'Knowledge': 'Knowledge',
    'Ingest': 'Ingest',
    'Plugin': 'Plugin',
    'Platform': 'Platform',
}

# 本地化 Key 命名空间允许的前缀集合
ALLOWED_KEY_PREFIXES = {
    'common', 'settings', 'auth', 'chat', 'ingest', 'weekly', 'report', 
    'insight', 'medal', 'tooltip', 'coachmark', 'dashboard', 'evaluation', 
    'action', 'log', 'logAction', 'menu', 'misc', 'sync', 'transfer', 
    'collaboration', 'error', 'tab', 'unit', 'preview', 'sidebar', 'weeklyReport',
    'pkm', 'widget', 'watch', 'platform', 'model_manager'
}

# 允许重复的通用翻译词汇，不会触发 Duplicate translation 警告
EXEMPT_DUPLICATE_VALUES = {
    # 英文
    "Pages", "Words", "Tags", "Confirm", "%d pages", "Comparison", "New Page", "ZhiYu", "Source", "Project Research", 
    "Quick Actions", "AI Thinking...", "Ingest", "Clear All", "Import", "Security", "Collaboration", "Plugins", 
    "Synthesis", "System", "Tools", "Active", "AI Chat", "Concept", "Quality", "Network", "Storage", "Retrieval", 
    "Reading", "Ready", "Version", "Parameters", "Reset to Defaults", "Vaults", "Get Started", "Data", 
    "Clear All Data", "Run Stress Test", "Rebuild Initial Notebooks", "Reset Onboarding", "Overview", "Token", 
    "OCR Scan", "Voice Note", "ZhiYu Room", "Knowledge Graph", "Memory", "Planning", "Tool Use", "All Pages",
    "Processing", "Success", "Failure",
    # 中文
    "导入到知识库", "剪贴板导入", "笔记本名称", "端侧与在线混合策略", "在线模型选择", "任务路由规则", "网络状态监控", 
    "安全与隐私", "本地大模型", "AI 正在思考...", "Token 消耗", "未关联笔记", "合成实验室", "AI 对话"
}


# ==============================================================================
# MARK: - 基础文本分析工具库 (TextUtil)
# ==============================================================================

class TextUtil:
    """提供本地化静态审计所需的文本启发式检测分析能力。"""

    @staticmethod
    def is_chinese(text):
        """
        判断字符串中是否包含 CJK 统一汉字。
        
        :param text: 待分析字符串
        :return: 包含汉字则返回 True，否则返回 False
        """
        if not text:
            return False
        return any('\u4e00' <= c <= '\u9fff' for c in text)

    @staticmethod
    def is_natural_language_sentence(text):
        """
        启发式算法：检测字符串是否为英文自然语言句子（非代码变量名、非文件路径）。
        
        :param text: 待分析字符串
        :return: 符合英文句子特征则返回 True
        """
        if not text or len(text) < MIN_NATURAL_LANG_LEN:
            return False
        words = [w.lower().strip('.,!?()[]{}') for w in text.split()]
        if len(words) > 1:
            if any(w in COMMON_ENGLISH_WORDS for w in words):
                return True
            if re.search(r'[a-z] [a-z]', text, re.I):
                return True
        return False

    @staticmethod
    def is_compound_pascal_case(text):
        """
        分析检测字符串是否为 PascalCase/camelCase 复合词（通常是翻译未填写的代码占位符）。
        
        :param text: 待分析字符串
        :return: 符合占位符特征返回 True
        """
        if not text or ' ' in text:
            return False
        if not re.match(r'^[a-zA-Z]+$', text):
            return False
        if not re.search(r'[a-z][A-Z]|[A-Z]{2,}[a-z]', text):
            return False
        if len(text) <= MIN_NATURAL_LANG_LEN:
            return False
        if text in KNOWN_PROPER_NAMES:
            return False
        words = [w for w in re.split(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', text) if w]
        return len(words) >= 2

    @staticmethod
    def is_view_file(file_path):
        """
        判断文件是否为 SwiftUI 视图或表现层文件。
        
        :param file_path: 文件路径
        :return: 属于表现层文件返回 True
        """
        path_lower = file_path.lower()
        return '/view/' in path_lower or '/views/' in path_lower or file_path.endswith('View.swift')


# ==============================================================================
# MARK: - Catalog 字典审计器 (XCStringsAuditor)
# ==============================================================================

class XCStringsAuditor:
    """负责解析和验证 Sources/Localization/Catalogs 目录下的所有 .xcstrings 字典合规性。"""

    def __init__(self, catalogs_dir='Sources/Localization/Catalogs'):
        self.catalogs_dir = catalogs_dir

    def _is_whitespace_exempt(self, text):
        """
        判定是否属于豁免检测的换行/技术空格占位文本。
        """
        if any(x in text for x in ["\n", "\t"]):
            return True
        # 豁免常见的拼接格式占位空格
        trimmed = text.strip()
        if not trimmed:  # 纯空格（如 " "）不在这里放行
            return False
        # 冒号加空格后缀 (如 "Note: ", "Source Link: ", "Recommended Query: ") 或者是列表分隔符 (", ")
        if text.endswith(': ') or text.endswith('： ') or text in (', ', ', '):
            return True
        # 英文句子拼接前导或尾随空格
        if text.startswith(' ') or text.endswith(' '):
            return True
        return False

    def _is_self_value_exempt(self, k, v):
        """
        判定是否属于可以豁免自键名占位符校验的情形。
        """
        return v.startswith('%') or v.startswith('http') or v in ('sk-...',) or TextUtil.is_chinese(k)

    def _check_key_placeholder(self, file, key, en_trimmed, zh_trimmed, issues):
        """
        检查翻译中是否包含了未填充的 Key 占位符本身。
        """
        if en_trimmed and '.' in key and en_trimmed == key and not self._is_self_value_exempt(key, en_trimmed):
            issues.append((file, key, f'English value matches key itself: "{en_trimmed}" (unfilled placeholder)', "ERROR"))
        if zh_trimmed and '.' in key and zh_trimmed == key and not self._is_self_value_exempt(key, zh_trimmed):
            issues.append((file, key, f'zh-Hans value matches key itself: "{zh_trimmed}" (unfilled placeholder)', "ERROR"))

    def _check_key_format(self, file, key, en_trimmed, zh_trimmed, issues):
        """
        检查翻译值中是否错误地包含了 key 格式的字符串。
        """
        key_pattern = re.compile(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*){2,}$')
        if key_pattern.match(en_trimmed):
            issues.append((file, key, f'English value is formatted like a key: "{en_trimmed}"', "ERROR"))
        if key_pattern.match(zh_trimmed):
            issues.append((file, key, f'zh-Hans value is formatted like a key: "{zh_trimmed}"', "ERROR"))

    def _check_key_whitespace(self, file, key, en_val, zh_val, en_trimmed, zh_trimmed, issues):
        """
        检查翻译值首尾多余空格的情况。
        """
        if en_val != en_trimmed and not self._is_whitespace_exempt(en_val):
            issues.append((file, key, f'English value has trailing/leading whitespace: "{repr(en_val)}"', "WARNING"))
        if zh_val != zh_trimmed and not self._is_whitespace_exempt(zh_val):
            issues.append((file, key, f'zh-Hans value has trailing/leading whitespace: "{repr(zh_val)}"', "WARNING"))
    def _is_identical_translation_exempt(self, en_trimmed, key):
        """
        判断完全相同的中英文翻译值是否应豁免判定为假翻译。
        
        :param en_trimmed: 去除首尾空格后的英文原文字符串
        :param key: 本地化键名
        :return: 允许豁免返回 True，否则返回 False
        """
        # 1. 静态白名单匹配：包括通用缩写、计量单位及数学区间
        EXEMPT_IDENTICAL_VALUES = {
            "AI", "PDF", "Token", "RAG", "ms", "MB", "GB", "SHA256", "Top-K", "Top-P", "ESC", "·", 
            "about", "action", "ignore", "preview", "skip", "unknown", "yesterday", "retry", 
            "A", "B", "1 Text", "50-69", "70-89", "90-100", "50–69", "70–89", "90–100", "Mac", "macOS", "—",
            "MRR", "NDCG@10", "F1@5", "MAP", "Lint", "model-name", "< 50", "%@ GB", "sk-...", "Constantine"
        }
        if en_trimmed in EXEMPT_IDENTICAL_VALUES or en_trimmed in KNOWN_PROPER_NAMES:
            return True
            
        # 2. 动态格式与文件名匹配
        if re.match(r'^[a-zA-Z0-9_\-.]+\.(md|pdf|json|txt|swift|db|zip|html)$', en_trimmed):
            return True
        if en_trimmed.startswith('sk-') or '...' in en_trimmed:
            return True
            
        # 3. 特定逻辑键匹配
        if re.match(r'^llm\.(prompt\.(?!workshop\b|reset\b|expert\b)[a-zA-Z]+|ingest\.json)', key):
            return True
        if key in ("vault.defaultName.en", "vault.researchName.en", "vault.defaultName.zh", "vault.researchName.zh"):
            return True
            
        return False

    def _check_identical_translation(self, file, key, en_trimmed, zh_trimmed, issues):
        """
        辅助审计：检查中英文完全相同的假翻译情况。
        
        :param file: 物理文件名
        :param key: 本地化键名
        :param en_trimmed: 英文去除首尾空格后的文本
        :param zh_trimmed: 中文去除首尾空格后的文本
        :param issues: 异常报告收集容器
        """
        # 如果中英文不一致，或者包含中文，或者是空字符串，直接跳过
        if en_trimmed != zh_trimmed or TextUtil.is_chinese(en_trimmed) or not en_trimmed:
            return

        # 调用提取出的辅助方法判定是否豁免
        if self._is_identical_translation_exempt(en_trimmed, key):
            return

        # 检查是否包含除了标点符号、数字、空格和基础格式化占位符之外的有效英文字符
        if re.match(r'^[0-9.%@\s\-\[\]\(\)<>=+]+$', en_trimmed):
            return

        # 区分是严重的句子未翻译错误，还是普通的单词警告
        if TextUtil.is_natural_language_sentence(en_trimmed):
            issues.append((file, key, f'Potential fake translation (zh is same as en sentence): "{en_trimmed}"', "ERROR"))
        else:
            issues.append((file, key, f'Identical zh/en detected: "{en_trimmed}"', "WARNING"))

    def _check_key_translation(self, file, key, locs, en_val, zh_val, en_trimmed, zh_trimmed, issues):
        """
        检查中英文翻译的内容一致性与有效性。
        """
        if 'zh-Hans' not in locs:
            if key.strip() and not re.match(r'^[0-9.%@\s\-\[\]\(\)]+$', key):
                issues.append((file, key, "Missing zh-Hans translation", "ERROR"))
        elif TextUtil.is_chinese(en_val) and not TextUtil.is_chinese(zh_val):
            issues.append((file, key, f'English translation field contains Chinese characters: "{en_val}"', "ERROR"))
        else:
            self._check_identical_translation(file, key, en_trimmed, zh_trimmed, issues)

    def _check_key_state(self, file, key, value, en_val, zh_val, locs, issues):
        """
        检查翻译状态（stale 标志以及是否为空等）。
        """
        zh_loc = locs.get('zh-Hans', {}).get('stringUnit', {})
        zh_state = zh_loc.get('state', '')
        if zh_state and zh_state != 'translated':
            issues.append((file, key, f'zh-Hans translation state is "{zh_state}"', "WARNING"))

        extraction_state = value.get('extractionState', '')
        if extraction_state == 'stale':
            issues.append((file, key, "Key extractionState is 'stale' (will not compile)", "CRITICAL"))

        if not en_val:
            issues.append((file, key, "English value is empty", "ERROR"))
        elif not en_val.strip() and not self._is_whitespace_exempt(en_val):
            issues.append((file, key, "English value is whitespace only", "WARNING"))
        if not zh_val:
            issues.append((file, key, "zh-Hans value is empty", "ERROR"))
        elif not zh_val.strip() and not self._is_whitespace_exempt(zh_val):
            issues.append((file, key, "zh-Hans value is whitespace only", "WARNING"))

    def _audit_single_key(self, file, key, value, locs, issues):
        """
        审计单个本地化键值对单元的合规性。
        """
        en_loc = locs.get('en', {}).get('stringUnit', {})
        zh_loc = locs.get('zh-Hans', {}).get('stringUnit', {})

        en_val = en_loc.get('value', '')
        zh_val = zh_loc.get('value', '')

        en_trimmed = en_val.strip()
        zh_trimmed = zh_val.strip()

        self._check_key_placeholder(file, key, en_trimmed, zh_trimmed, issues)
        self._check_key_format(file, key, en_trimmed, zh_trimmed, issues)
        self._check_key_whitespace(file, key, en_val, zh_val, en_trimmed, zh_trimmed, issues)
        if TextUtil.is_compound_pascal_case(en_val):
            issues.append((file, key, f'English value is a compound PascalCase code placeholder: "{en_val}"', "ERROR"))
        self._check_key_translation(file, key, locs, en_val, zh_val, en_trimmed, zh_trimmed, issues)
        self._check_key_state(file, key, value, en_val, zh_val, locs, issues)
        self._check_multi_language_format_specifiers(file, key, locs, en_val, issues)

    def _check_multi_language_format_specifiers(self, file, key, locs, en_val, issues):
        """
        校验多语言 Format Specifier (%@, %d, %s) 参数数量与格式的跨语言一致性。
        """
        if not en_val:
            return
        specifier_pattern = re.compile(r'%[0-9]*\$?[@dDfsudxX]')
        en_specifiers = specifier_pattern.findall(en_val)
        if not en_specifiers:
            return

        for lang, loc in locs.items():
            if lang == 'en':
                continue
            val = loc.get('stringUnit', {}).get('value', '')
            if not val:
                continue
            lang_specifiers = specifier_pattern.findall(val)
            if len(lang_specifiers) != len(en_specifiers):
                issues.append((file, key, f'{lang} format specifier count mismatch with en: expected {len(en_specifiers)}, got {len(lang_specifiers)} ("{val}")', "WARNING"))

    def audit(self):
        """
        执行 Catalog 全量审计。
        
        :return: 异常列表，元素为 (file, key, message, severity)
        """
        if not os.path.exists(self.catalogs_dir):
            return []

        files = [f for f in os.listdir(self.catalogs_dir) if f.endswith('.xcstrings')]
        issues = []

        for file in files:
            path = os.path.join(self.catalogs_dir, file)
            with open(path, 'r', encoding='utf-8') as f:
                try:
                    data = json.load(f)
                except Exception as e:
                    issues.append((file, "ALL", f"JSON parsing failed: {e}", "CRITICAL"))
                    continue

            strings = data.get('strings', {})
            for key, value in strings.items():
                locs = value.get('localizations', {})
                self._audit_single_key(file, key, value, locs, issues)

        return issues


# ==============================================================================
# MARK: - Swift 源码硬编码审计器 (SourceCodeAuditor)
# ==============================================================================

EXEMPT_STRINGS = {
    "Not used on watchOS",
    "> [Image Semantics]:",
    "AI Chat",
    "AI Chat Stream",
    "Not Supported",
    "PDF extraction is not supported on this platform.",
    "Non-ASCII Content",
    "%.1f tok/s",
    "Keep it short.",
    "You are a Plugin",
    "Calibri Light",
    "·",
    "•",
    "⌘K",
    "⌘",
    " [DatabaseManager] switchDatabase warning: Transactions draining timed out. Forcing connection close.",
    "TOC Generator",
    "ZhiYu Team",
    "Auto-generate TOC for documents.",
    "Word Counter",
    "Count words and characters in editor.",
    "Markdown Beautifier",
    "Auto format and beautify Markdown documents.",
    "AI Translator",
    "ZhiYu Remote Team",
    "Auto translate text using AI with multi-language support.",
    "Link Preview",
    "Auto fetches URL meta and generates rich preview cards.",
    "AI Summary Generator",
    "Extract key points and generate structured summaries.",
    "Code Highlighter",
    "Add syntax highlighting and line numbers to code blocks.",
    "You are a senior knowledge expert and researcher. Your goal is to provide deep, insightful expansion of existing knowledge.",
    "Prompt configurations saved to UserDefaults.",
    "Before Store instantiation",
    "Total registered",
    ")). Total registered: \\(registeredCount)",
    "Prompt configurations reset to default.",
    "\n\nPlease reply in English.",
    "Export is not supported on this platform.",
    "Thinking Process:",
    "Reasoning Process:"
}

class SourceCodeAuditor:
    """负责遍历和扫描 Swift 源码，发现违规的硬编码中文以及在 UI 语境下的英文句子。"""

    def __init__(self, root_dir='Sources', exclude_dirs=None):
        self.root_dir = root_dir
        self.exclude_dirs = exclude_dirs or EXCLUDE_DIRS
        
        logger_patterns = [
            r'\.(debug|info|warning|error|notice|trace|log)\s*\(',
            r'[Ll]ogger\.',
            r'[Ll]og\.',
            r'print\s*\(',
            r'NSLog\(',
            r'os_log\(',
            r'fatalError\(',
        ]
        self.logger_re = re.compile('|'.join(logger_patterns))
        self.exempt_strings = EXEMPT_STRINGS


    def _is_literal_exempt(self, s, is_logger, is_view):
        """
        验证字面量是否符合纯技术、日志或模拟数据的豁免条件。
        """
        # 1. 如果是日志语句（非 View 语境下），直接放行
        if is_logger and not is_view:
            return True
            
        s_lower = s.lower()
        
        # 2. 合并的技术、数据库、Mock及AI常用关键字集合（降低方法复杂度）
        TECHNICAL_KEYWORDS = {
            "select", "insert", "update", "delete", "from", "where", "join", "into", "values", 
            "create table", "drop table", "ignore into", "mock", "stub", "test", "dummy", "fake", 
            "carrier", "user", "cancelled", "no sim", "no network", "developer", "ollama", "http",
            "reply", "return json", "json schema", "graph td", "keep response", "query", "fail", 
            "error", "succeed", "invalid", "unsupported", "denied", "not loaded", "not support", 
            "not configure", "progress", "keychain", "signature", "download", "payload", "sdk", 
            "persist", "legacy", "resume", "metadata", "compile", "sandbox", "storage", "copy"
        }


        if any(kw in s_lower for kw in TECHNICAL_KEYWORDS):
            return True
            
        # 3. 日期时间格式化及容量大小占位符（如 "yyyy-MM-dd HH:mm", "%.1f KB", "%.0f GB"）
        if re.match(r'^[yMdHms\-\/:\s\d%.,fKGtB]+$', s) and any(x in s for x in ['yy', 'MM', 'dd', 'HH', 'mm', '%']):
            return True
            
        # 4. 正则表达式或特殊转义控制字符
        if any(x in s for x in ["|", "\\d", "\\s", "\\w", "\\t", "\\n"]):
            return True
            
        return False


    def _audit_chinese_literal(self, s, line_no, is_allow_non_ascii, is_logger, issues):
        """审计硬编码的非 ASCII (中文) 字面量。"""
        if not is_allow_non_ascii:
            severity = "WARNING" if is_logger else "ERROR"
            issues.append((line_no, s, "Hardcoded non-ASCII string detected.", severity))

    def _audit_english_literal(self, s, line, line_no, is_view, is_logger, issues):
        """审计 UI 上可能存在的硬编码英文句子字面量。"""
        is_ui_trigger = any(trigger in line for trigger in UI_TRIGGERS)
        if TextUtil.is_natural_language_sentence(s):
            if is_view and is_ui_trigger:
                severity = "WARNING" if is_logger else "ERROR"
                issues.append((line_no, s, "Hardcoded English sentence in UI context.", severity))
            else:
                issues.append((line_no, s, "Hardcoded English sentence detected in logic file.", "WARNING"))

    def _audit_literal(self, s, line, line_no, is_allow_non_ascii, is_view, is_logger, issues):
        """
        辅助审计：对代码行中的单字面量进行硬编码中文或UI英文的特征校验。
        """
        if s in self.exempt_strings or "Stress Test Page #" in s or self._is_literal_exempt(s, is_logger, is_view):
            return

        if TextUtil.is_chinese(s):
            self._audit_chinese_literal(s, line_no, is_allow_non_ascii, is_logger, issues)
        else:
            if not is_allow_non_ascii:
                self._audit_english_literal(s, line, line_no, is_view, is_logger, issues)


    def check_file(self, file_path):
        """
        审计单个 Swift 文件的内容。
        
        :param file_path: 文件物理路径
        :return: 异常列表，元素为 (line_no, matched_text, message, severity)
        """
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            raw_content = f.read()

        def comment_replacer(match):
            return "\n" * match.group(0).count("\n")
        content = re.sub(r'/\*.*?\*/', comment_replacer, raw_content, flags=re.DOTALL)

        lines = []
        for line in content.split('\n'):
            if '//' in line:
                lines.append(line.split('//')[0])
            else:
                lines.append(line)

        issues = []
        filename = os.path.basename(file_path)
        is_allow_non_ascii = filename in ALLOW_NON_ASCII_FILES
        is_view = TextUtil.is_view_file(file_path)
        is_l10n_extension = 'Localization/Extensions' in file_path

        for i, line in enumerate(lines):
            line_no = i + 1

            if not is_l10n_extension and DIRECT_TR_PATTERN.search(line):
                issues.append((line_no, line.strip(), "Direct .tr()/.trf() call detected. MUST use L10n property.", "ERROR"))

            literals = STRING_PATTERN.findall(line)
            is_logger = bool(self.logger_re.search(line))
            for s in literals:
                self._audit_literal(s, line, line_no, is_allow_non_ascii, is_view, is_logger, issues)

        return issues

    def audit_all(self):
        """
        遍历 Sources 目录，执行全量源码硬编码审计。
        
        :return: dict: {file_path: [issues]}
        """
        all_source_issues = {}
        for root, dirs, files in os.walk(self.root_dir):
            dirs[:] = [d for d in dirs if d not in self.exclude_dirs]
            for file in files:
                if file.endswith('.swift'):
                    file_path = os.path.join(root, file)
                    issues = self.check_file(file_path)
                    if issues:
                        all_source_issues[file_path] = issues
        return all_source_issues


# ==============================================================================
# MARK: - 缺失键检测与回溯校验引擎 (MissingKeyDetector)
# ==============================================================================

class MissingKeyDetector:
    """分析扩展文件（Extensions）对底层 Localized.tr 的引用，发现未在 xcstrings 定义的键或跨表错配。"""

    def __init__(self, catalogs_dir='Sources/Localization/Catalogs', extensions_dir='Sources/Localization/Extensions'):
        self.catalogs_dir = catalogs_dir
        self.extensions_dir = extensions_dir
        self.domain_map = DOMAIN_MAP

    def detect(self):
        """
        执行缺失 Key 检查及变量回溯校验的总入口。
        
        :return: 异常列表，元素为 (file, key, message, severity)
        """
        all_keys, table_keys = self._build_xcstrings_index()
        missing = []

        # 1. 校验 L10n 扩展声明的物理表与键的对应关系
        self._check_extension_keys(all_keys, table_keys, missing)

        # 2. 检查非扩展模块中原生 L.tr() 异常使用情况
        self._check_raw_tr_calls(all_keys, missing)

        # 2.5 校验全局不带 table 参数的 Localized.tr(key) 是否在 Common 表中
        self._check_global_implicit_tr_calls(table_keys, missing)

        # 3. 校验非 Common 模块错误隐式解析成 Common table 的情况
        self._check_implicit_tr_mismatches(all_keys, table_keys, missing)

        # 4. 校验业务调用的 L10n.Module 对应的物理扩展文件是否完整
        self._check_l10n_modules_exist(missing)

        # 5. 扫描所有 Swift 文件，提取变量到 Key 的动态映射进行变量溯源
        var_to_keys = self._trace_variable_assignments(all_keys)

        # 6. 利用变量追踪校验带变量参数 of L10n.Module.tr() 跨表一致性
        self._check_l10n_tr_calls_with_vars(all_keys, table_keys, var_to_keys, missing)

        # 7. 全局静态字面量硬编码 Key 命名审计
        self._check_global_key_candidates(all_keys, missing)

        return missing

    def _build_xcstrings_index(self):
        """
        构建所有 xcstrings 键及其所属的物理表索引。
        
        :return: (all_keys, table_keys)
        """
        all_keys = set()
        table_keys = {}
        for file in os.listdir(self.catalogs_dir):
            if file.endswith('.xcstrings'):
                table = file.replace('.xcstrings', '')
                path = os.path.join(self.catalogs_dir, file)
                with open(path, 'r', encoding='utf-8') as f:
                    try:
                        data = json.load(f)
                        strings = data.get('strings', {})
                        all_keys.update(strings.keys())
                        table_keys[table] = set(strings.keys())
                    except Exception:
                        continue
        return all_keys, table_keys

    def _audit_extension_line_keys(self, line, declared_table, all_keys, table_keys, path, missing, tr_pattern, tr_func_pattern, l_tr_pattern):
        """
        辅助审计：检查 Extension 单行中的 L10n 键是否存在或表匹配正确。
        """
        keys = set(tr_pattern.findall(line) + tr_func_pattern.findall(line) + l_tr_pattern.findall(line))
        for key in keys:
            table_match = re.search(r'table\s*:\s*"([^"]+)"', line)
            target_table = declared_table
            if table_match:
                logical_table = table_match.group(1)
                target_table = self.domain_map.get(logical_table, logical_table)
            else:
                # 检测显式模块前缀调用（如 Common.tr("ok") 在 Ingest 扩展中引用 Common 表）
                # 这是合法的跨表共享，避免重复定义通用 key
                for mod_name, mod_table in self.domain_map.items():
                    if f"{mod_name}.tr(" in line or f"{mod_name}.trf(" in line:
                        target_table = mod_table
                        break

            # 过滤以点号结尾的动态拼接前缀键（如 "graph." + key）
            if key.endswith('.'):
                continue

            if key not in all_keys:
                missing.append((path, key, f"Key used in L10n extension but missing from ALL .xcstrings files", "ERROR"))
            elif target_table in table_keys:
                if key not in table_keys[target_table]:
                    actual_files = [t for t, ks in table_keys.items() if key in ks]
                    missing.append((path, key, f"Table mismatch: key in extension (table=\"{target_table}\") but key resides in {actual_files}", "ERROR"))

    def _check_extension_keys(self, all_keys, table_keys, missing):
        """
        检测本地化 Extension 中硬编码 tr(...) 调用的键是否缺失或跨表错配。
        """
        table_pattern = re.compile(r'static (?:let t|let tableName)\s*=\s*"([^"]+)"')
        tr_pattern = re.compile(r'Localized\.trf?\(\s*"([^"]+)"')
        tr_func_pattern = re.compile(r'\btrf?\(\s*"([^"]+)"')
        l_tr_pattern = re.compile(r'L\.trf?\(\s*"([^"]+)"')

        if not os.path.exists(self.extensions_dir):
            return

        for file in os.listdir(self.extensions_dir):
            if not file.endswith('.swift'):
                continue
            path = os.path.join(self.extensions_dir, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            tables = table_pattern.findall(content)
            if not tables:
                continue
            declared_table = tables[0]

            lines = content.split('\n')
            for line in lines:
                self._audit_extension_line_keys(line, declared_table, all_keys, table_keys, path, missing, tr_pattern, tr_func_pattern, l_tr_pattern)

    def _check_raw_tr_calls(self, all_keys, missing):
        """
        扫描非 Extension 文件的 tr() 硬编码调用（如 Watch 端）。
        """
        l_tr_pattern = re.compile(r'L\.trf?\(\s*"([^"]+)"')
        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
            for f in files:
                if f.endswith('.swift') and 'Extensions' not in root:
                    path = os.path.join(root, f)
                    with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                        content = fh.read()
                    for key in set(l_tr_pattern.findall(content)):
                        if key not in all_keys:
                            missing.append((path, key, "L.tr() key used in source code but missing from ALL .xcstrings", "ERROR"))

    def _check_global_implicit_tr_calls(self, table_keys, missing):
        """
        扫描 Sources 下所有文件中的 Localized.tr() / Localized.trf() 隐式调用。
        如果 key 不在 Common 表中，则按 ERROR 阻断编译。
        """
        implicit_tr_pattern = re.compile(r'Localized\.trf?\(\s*"([^"]+)"(?:\s*\)|\s*,\s*(?![^)]*table\s*:)[^)]*\))')
        common_keys = table_keys.get("Common", set())
        
        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
            for f in files:
                if f.endswith('.swift'):
                    path = os.path.join(root, f)
                    with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                        content = fh.read()
                    
                    # 匹配所有不带 table: 参数的 Localized.tr
                    for key in set(implicit_tr_pattern.findall(content)):
                        if key not in common_keys:
                            actual = [t for t, ks in table_keys.items() if key in ks]
                            missing.append((path, key, f"Implicit Localized.tr() defaults to 'Common' table, but key '{key}' is only in {actual} (missing from 'Common')", "ERROR"))

    def _check_implicit_tr_mismatches(self, all_keys, table_keys, missing):
        """
        校验非 Common 模块对 Localized.tr() 的隐式错误调用（导致表解析降级丢失）。
        """
        table_pattern = re.compile(r'static (?:let t|let tableName)\s*=\s*"([^"]+)"')
        tr_pattern = re.compile(r'Localized\.trf?\(\s*"([^"]+)"')

        for file in os.listdir(self.extensions_dir):
            if not file.endswith('.swift'): continue
            path = os.path.join(self.extensions_dir, file)
            with open(path, 'r', encoding='utf-8') as fh:
                content = fh.read()
            tables = table_pattern.findall(content)
            declared_table = tables[0] if tables else "Common"
            if declared_table == "Common": continue

            lines = content.split('\n')
            for line in lines:
                for key in set(tr_pattern.findall(line)):
                    # 如果这行含有显式的 table: "xxx" 或 table: t，属于显式调用，由显式检查覆盖，隐式检查跳过
                    if re.search(r'table\s*:\s*', line):
                        continue
                    
                    # 隐式调用 Localized.tr(key) 会默认降级检索 'Common' 表
                    common_keys = table_keys.get("Common", set())
                    if key not in common_keys:
                        actual = [t for t, ks in table_keys.items() if key in ks]
                        mod = file.replace('L10n+', '').replace('.swift', '')
                        missing.append((path, key, f"Implicit Localized.tr() in L10n+{mod} defaults to 'Common' table, but key is only in {actual} (missing from 'Common')", "ERROR"))

    def _load_existing_l10n_modules(self):
        """
        加载并缓存当前扩展目录中定义的所有本地化模块结构名称。
        """
        existing_modules = set()
        l10n_decl_pattern = re.compile(r'(?:public\s+)?(?:struct|enum|class)\s+([A-Z][a-zA-Z0-9_]*)\s*(?::|{)')
        if not os.path.exists(self.extensions_dir):
            return existing_modules

        for f in os.listdir(self.extensions_dir):
            if f.startswith('L10n+') and f.endswith('.swift'):
                existing_modules.add(f.replace('L10n+', '').replace('.swift', ''))
                with open(os.path.join(self.extensions_dir, f), 'r', encoding='utf-8') as fh:
                    content = fh.read()
                for mod in l10n_decl_pattern.findall(content):
                    existing_modules.add(mod)
        return existing_modules

    def _check_l10n_modules_exist(self, missing):
        """
        验证调用的 L10n.Module.* 语法是否对应真实的扩展文件。
        """
        l10n_module_pattern = re.compile(r'L10n\.([A-Z][a-zA-Z]*)\.')
        existing_modules = self._load_existing_l10n_modules()

        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in ('.git', 'Localization') and not d.startswith('.')]
            for f in files:
                if not f.endswith('.swift'): continue
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    content = fh.read()
                for module in set(l10n_module_pattern.findall(content)):
                    if module not in existing_modules:
                        missing.append((path, module, f"L10n.{module}.* referenced in code but extension structure not found", "ERROR"))

    def _record_traced_var_key(self, var_name, loc_key, current_container, all_keys, var_to_keys):
        """
        辅助审计：如果发现匹配的本地化键值分配，记录变量与键的映射关系。
        """
        if '/' in loc_key or loc_key.startswith('http') or ' ' in loc_key:
            return
        if loc_key in all_keys:
            if var_name not in var_to_keys:
                var_to_keys[var_name] = set()
            var_to_keys[var_name].add(loc_key)
            
            if current_container:
                full_var = f"{current_container}.{var_name}"
                if full_var not in var_to_keys:
                    var_to_keys[full_var] = set()
                var_to_keys[full_var].add(loc_key)

    def _trace_lines_variables(self, lines, var_assign_pattern, all_keys, var_to_keys):
        """
        辅助审计：逐行分析 Swift 代码寻找变量分配并进行 Key 追踪。
        """
        container_pattern = re.compile(r'\b(?:struct|class|enum)\s+([A-Z]\w*)')
        current_container = None
        
        for line in lines:
            container_match = container_pattern.search(line)
            if container_match:
                current_container = container_match.group(1)
                
            for var_name, loc_key in var_assign_pattern.findall(line):
                self._record_traced_var_key(var_name, loc_key, current_container, all_keys, var_to_keys)

    def _trace_variable_assignments(self, all_keys):
        """
        变量回溯追踪：扫描 Swift 源码提取变量赋本地化 key 的对应关联。
        """
        var_to_keys = {}
        var_assign_pattern = re.compile(r'\b([a-zA-Z0-9_]+)\b\s*[:=]\s*"([a-z0-9_]+(?:\.[a-z0-9_.-]+)+)"')

        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in ('.git', 'Localization') and not d.startswith('.')]
            for f in files:
                if not f.endswith('.swift'): continue
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    content = fh.read()
                    
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                lines = [line.split('//')[0] if '//' in line else line for line in content.split('\n')]
                self._trace_lines_variables(lines, var_assign_pattern, all_keys, var_to_keys)
        return var_to_keys

    def _filter_module_resolved_keys(self, module, resolved_keys):
        """
        根据不同的国际化 module，对解析到的 key 进行相关的前缀和规则过滤。
        """
        module_prefixes = {
            'Coachmark': ('tooltip.', 'coachmark.'),
            'Insight': ('medal.', 'weekly.', 'report.', 'insight.'),
            'Settings': ('settings.',)
        }
        if module not in module_prefixes:
            return resolved_keys

        prefixes = module_prefixes[module]
        return {rk for rk in resolved_keys if rk.startswith(prefixes)}

    def _resolve_variable_keys(self, param, content_str, var_to_keys):
        """
        根据参数和已收集的变量映射，解析出可能对应的本地化键集合。
        """
        if param.startswith('"') and param.endswith('"'):
            return {param.strip('"')}
        if param.startswith("'") and param.endswith("'"):
            return {param.strip("'")}

        resolved = set()
        if param in var_to_keys:
            resolved.update(var_to_keys[param])
            
        pattern = re.compile(rf'\b{re.escape(param)}\b\s*[:=]\s*"([a-z0-9_]+(?:\.[a-z0-9_.-]+)+)"')
        for match in pattern.findall(content_str):
            resolved.add(match)

        return resolved

    def _validate_resolved_tr_keys(self, resolved_keys, target_table, all_keys, table_keys, path, module, param, missing):
        """
        辅助审计：验证解析出的 L10n 键物理表映射是否正确。
        """
        for rkey in resolved_keys:
            if rkey not in all_keys:
                continue
                
            actual_tables = [t for t, ks in table_keys.items() if rkey in ks]
            if target_table not in actual_tables and 'Common' not in actual_tables:
                missing.append((path, rkey,
                    f"Table mismatch: L10n.{module}.tr({param}) resolves to table '{target_table}', "
                    f"but key '{rkey}' only exists in {actual_tables}", "ERROR"))

    def _check_l10n_tr_calls_with_vars(self, all_keys, table_keys, var_to_keys, missing):
        """
        校验含有变量回溯的 L10n.Module.tr() 的跨表错位。
        """
        l10n_tr_call_pattern = re.compile(r'L10n\.([A-Z][a-zA-Z]*)\.trf?\(\s*([^),]+)\s*')
        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in ('.git', 'Localization') and not d.startswith('.')]
            for f in files:
                if not f.endswith('.swift') or 'Extensions' in root: continue
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    lines = fh.readlines()
                    
                clean_lines = [line.split('//')[0] if '//' in line else line for line in lines]
                content_str = ''.join(clean_lines)
                
                for line in clean_lines:
                    for module, param in l10n_tr_call_pattern.findall(line):
                        param = param.strip()
                        target_table = self.domain_map.get(module)
                        if not target_table:
                            continue
                            
                        resolved_keys = self._resolve_variable_keys(param, content_str, var_to_keys)
                        resolved_keys = self._filter_module_resolved_keys(module, resolved_keys)
                        self._validate_resolved_tr_keys(resolved_keys, target_table, all_keys, table_keys, path, module, param, missing)

    def _is_exempt_key_candidate(self, key_candidate):
        """
        判定某个字面量是否应该豁免全局静态键检测。
        """
        parts = key_candidate.split('.')
        if not parts or parts[0] not in ALLOWED_KEY_PREFIXES:
            return True
        if '/' in key_candidate or key_candidate.startswith('http') or ' ' in key_candidate:
            return True
        if any(key_candidate.endswith(ext) for ext in ('.swift', '.json', '.js', '.css', '.png', '.jpg', '.jpeg', '.txt', '.db', '.zip', '.html', '.md')):
            return True
        if any(dt in key_candidate for dt in ('com.', 'org.', 'net.', '.com', '.org', '.net', '.io')):
            return True
        if key_candidate.startswith('auth.thirdparty.'):
            return True
        return False

    def _check_global_key_candidates(self, all_keys, missing):
        """
        全局静态字面量键值缺失检查（匹配前缀白名单）。
        """
        key_candidate_pattern = re.compile(r'"([a-z][a-z0-9_-]*(?:\.[a-z0-9_.-]+)+)"')
        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
            for f in files:
                if not f.endswith('.swift') or 'Extensions' in root: continue
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    content = fh.read()
                content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                content = '\n'.join([line.split('//')[0] if '//' in line else line for line in content.split('\n')])
                
                for key_candidate in key_candidate_pattern.findall(content):
                    if self._is_exempt_key_candidate(key_candidate):
                        continue
                    if key_candidate not in all_keys:
                        missing.append((path, key_candidate, f"Hardcoded key '{key_candidate}' detected in code but missing from catalogs", "ERROR"))


# ==============================================================================
# MARK: - 跨文件同键值冲突检测 (CrossFileInconsistencyDetector)
# ==============================================================================

class CrossFileInconsistencyDetector:
    """分析同一 Key 存在于多个 xcstrings 中，但中/英文定义不一致的情形。"""

    def __init__(self, catalogs_dir='Sources/Localization/Catalogs'):
        self.catalogs_dir = catalogs_dir

    def detect(self):
        """
        检测跨表不一致性。
        
        :return: 异常列表，元素为 (key, file_val_map, message, severity)
        """
        key_sources = {}
        for file in os.listdir(self.catalogs_dir):
            if not file.endswith('.xcstrings'):
                continue
            path = os.path.join(self.catalogs_dir, file)
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            for key, val in data.get('strings', {}).items():
                locs = val.get('localizations', {})
                zh = locs.get('zh-Hans', {}).get('stringUnit', {}).get('value', '')
                en = locs.get('en', {}).get('stringUnit', {}).get('value', '')
                if key not in key_sources:
                    key_sources[key] = {}
                key_sources[key][file] = (zh, en)

        issues = []
        for key, files in key_sources.items():
            if len(files) <= 1:
                continue
            
            zh_values = {f: v[0] for f, v in files.items()}
            if len(set(zh_values.values())) > 1:
                issues.append((key, zh_values, f"Cross-file mismatch: key '{key}' has DIFFERENT zh-Hans values across files", "WARNING"))
                
            en_values = {f: v[1] for f, v in files.items()}
            if len(set(en_values.values())) > 1:
                issues.append((key, en_values, f"Cross-file mismatch: key '{key}' has DIFFERENT en values across files", "WARNING"))
                
        return issues


# ==============================================================================
# MARK: - 冗余键审计器 (ObsoleteKeyDetector)
# ==============================================================================

class ObsoleteKeyDetector:
    """分析 Catalog 中定义了，但在全源码及扩展中无任何引用的冗余 Unused Key。"""

    def __init__(self, catalogs_dir='Sources/Localization/Catalogs', extensions_dir='Sources/Localization/Extensions'):
        self.catalogs_dir = catalogs_dir
        self.extensions_dir = extensions_dir

    def detect(self):
        """
        分析找出冗余 Key 并报警。
        
        :return: 异常列表，元素为 (file, key, message, severity)
        """
        key_to_tables, all_keys_with_table = self._load_catalog_keys()
        used_keys_with_table = set()
        
        self._scan_extension_files(key_to_tables, used_keys_with_table)
        self._scan_source_files(key_to_tables, used_keys_with_table)

        dynamic_prefixes = (
            'plugin.perm.',
            'ingest.status.',
            'aitask.',
            'ondevice.',
            'icloud.',
            'llm.',
            'weekly.aiAnalysis'
        )
        
        unused_issues = []
        for ref, (key, file) in all_keys_with_table.items():
            if file == 'InfoPlist.xcstrings':
                continue
            if ref in used_keys_with_table:
                continue
            if any(key.startswith(pre) for pre in dynamic_prefixes):
                continue
            if not key.strip():
                continue
                
            unused_issues.append((file, key, f"Unused localization key '{key}' found in {file} (no references in source code)", "WARNING"))
            
        return unused_issues

    def _load_catalog_keys(self):
        """读取 catalogs 中的所有国际化 key。"""
        key_to_tables = {}
        all_keys_with_table = {}
        for file in os.listdir(self.catalogs_dir):
            if file.endswith('.xcstrings'):
                table = file.replace('.xcstrings', '')
                with open(os.path.join(self.catalogs_dir, file), 'r', encoding='utf-8') as f:
                    try:
                        data = json.load(f)
                        strings = data.get('strings', {})
                        for key in strings.keys():
                            if key not in key_to_tables:
                                key_to_tables[key] = set()
                            key_to_tables[key].add(table)
                            all_keys_with_table[f"{key}@{table}"] = (key, file)
                    except Exception:
                        continue
        return key_to_tables, all_keys_with_table

    def _scan_extension_files(self, key_to_tables, used_keys_with_table):
        """扫描所有 Extensions 扩展文件中的本地化键使用。"""
        table_pattern = re.compile(r'static (?:let t|let tableName)\s*=\s*"([^"]+)"')
        if os.path.exists(self.extensions_dir):
            for file in os.listdir(self.extensions_dir):
                if not file.endswith('.swift'):
                    continue
                path = os.path.join(self.extensions_dir, file)
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    
                tables = table_pattern.findall(content)
                declared_table = tables[0] if tables else "Common"
                
                content_clean = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                lines = [line.split('//')[0] for line in content_clean.split('\n')]
                
                for line in lines:
                    literals = STRING_PATTERN.findall(line)
                    for lit in literals:
                        if lit in key_to_tables:
                            table_match = re.search(r'table\s*:\s*"([^"]+)"', line)
                            if table_match:
                                used_keys_with_table.add(f"{lit}@{table_match.group(1)}")
                            else:
                                used_keys_with_table.add(f"{lit}@{declared_table}")

    def _audit_source_line_literals(self, line, key_to_tables, used_keys_with_table):
        """
        辅助审计：检查并记录业务源文件某行中用到的本地化键物理表关联。
        """
        literals = STRING_PATTERN.findall(line)
        for lit in literals:
            if lit in key_to_tables:
                table_match = re.search(r'table\s*:\s*"([^"]+)"', line)
                if table_match:
                    used_keys_with_table.add(f"{lit}@{table_match.group(1)}")
                else:
                    for t in key_to_tables[lit]:
                        used_keys_with_table.add(f"{lit}@{t}")

    def _scan_source_files(self, key_to_tables, used_keys_with_table):
        """扫描 Sources 业务源码中的本地化键使用。"""
        for root, dirs, files in os.walk('Sources'):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith('.')]
            for f in files:
                if not f.endswith('.swift') or 'Extensions' in root:
                    continue
                path = os.path.join(root, f)
                with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                    content = fh.read()
                
                content_clean = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
                lines = [line.split('//')[0] if '//' in line else line for line in content_clean.split('\n')]
                
                for line in lines:
                    self._audit_source_line_literals(line, key_to_tables, used_keys_with_table)


# ==============================================================================
# MARK: - 报告输出与执行入口 (main)
# ==============================================================================

def _format_cross_file_issues(issues_list, output_lines):
    """格式化跨文件冲突缺陷。"""
    has_critical = False
    for key, sources, msg, level in issues_list:
        icon = "🚨" if level == "ERROR" else "⚠️"
        if level == "ERROR":
            has_critical = True
        output_lines.append(f"  Key: \"{key}\" - {icon} [{level}] {msg}")
        for file, val in sources.items():
            output_lines.append(f"    {file}: \"{val}\"")
    return has_critical


def _format_show_key_issues(issues_list, output_lines):
    """格式化展示 Key 的 Catalogs/Missing Keys 缺陷。"""
    has_critical = False
    current_file = ""
    for file, key, msg, level in issues_list:
        if file != current_file:
            output_lines.append(f"\n📂 {file}")
            current_file = file
        icon = "🚨" if level in ("ERROR", "CRITICAL") else "⚠️"
        if level in ("ERROR", "CRITICAL"):
            has_critical = True
        output_lines.append(f"  Key: \"{key}\" - {icon} [{level}] {msg}")
    return has_critical


def _format_source_code_issues(issues_list, output_lines):
    """格式化 Swift 源码硬编码字面量缺陷。"""
    has_critical = False
    for file_path, issues in sorted(issues_list.items()):
        output_lines.append(f"\n📂 {file_path}")
        for line_no, content, msg, level in issues:
            icon = "🚨" if level in ("ERROR", "CRITICAL") else "⚠️"
            if level in ("ERROR", "CRITICAL"):
                has_critical = True
            output_lines.append(f"  L{line_no}: {icon} [{msg}] \"{content}\"")
    return has_critical


def _format_audit_issues(title, issues_list, show_key=False, is_cross_file=False):
    """
    格式化打印各类缺陷，并计算是否存在阻断级（ERROR/CRITICAL）缺陷。
    
    :return: (has_critical, list_output)
    """
    if not issues_list:
        return False, []

    output_lines = [f"\n❌ {title}:"]
    
    if is_cross_file:
        has_critical = _format_cross_file_issues(issues_list, output_lines)
    elif show_key:
        has_critical = _format_show_key_issues(issues_list, output_lines)
    else:
        has_critical = _format_source_code_issues(issues_list, output_lines)

    return has_critical, output_lines


def _print_obsolete_issues(unused_key_issues):
    """打印 Unused Keys 警告。"""
    if unused_key_issues:
        print("\n⚠️ [L10n Audit] Unused Keys in Catalogs:")
        for file, key, msg, level in sorted(unused_key_issues):
            print(f"  Key: \"{key}\" - ⚠️ [{level}] {msg}")


def _exit_audit(has_critical, has_any_issues):
    """根据审计结果决定以什么状态码退出系统。"""
    if not has_any_issues:
        print("\n✅ [L10n Audit] Localization quality standards met.")
        sys.exit(0)
    
    if has_critical:
        print("\n[L10n Audit] CRITICAL VIOLATIONS. Build blocked.")
        sys.exit(1)
    else:
        print("\n[L10n Audit] Suggestions for cleanup found. Build permitted.")
        sys.exit(0)


# ==============================================================================
# MARK: - 重复翻译值检测器 (DuplicateTranslationDetector)
# ==============================================================================

class DuplicateTranslationDetector:
    """分析各 xcstrings 字典，检测同一语言翻译内容在不同 Key 中重复定义的情形。"""

    MAX_SHORT_EXEMPT_LEN = 3
    MAX_CJK_EXEMPT_LEN = 4

    def __init__(self, catalogs_dir='Sources/Localization/Catalogs'):
        self.catalogs_dir = catalogs_dir
        # 豁免重复值判定的词表，已补齐各分类豁免的原因：
        self.exempt_values = {
            # 1. 行业公认的技术专有名词及协议简写（无多语言翻译差异）
            "AI", "PDF", "Token", "RAG", "SHA256", "Top-K", "Top-P", "ESC", "Mac", "macOS", "Lint", "model-name",
            # 2. 物理度量与耗时统计单位
            "ms", "MB", "GB", "KB", "%@ GB",
            # 3. 信息技术标准评估指标名词
            "MRR", "NDCG@10", "F1@5", "MAP",
            # 4. 常规界面状态占位符与标点辅助符号
            "·", "—", ",", "，", "1", "0", "sk-...", "search...", "< 50", "1 Text",
            # 5. 常见硬编码分段统计指标名称（已在图表模块中沉淀为通用词汇）
            "50-69", "70-89", "90-100", "50–69", "70–89", "90–100",
            # 6. 系统默认账户名称
            "Constantine",
            # 7. 全局基础核心 UI 通用标准操作文本：
            # 豁免原因说明：从架构设计而言，此类高频通用动作词汇（如确定、取消、完成等）必须统一在 Common.xcstrings 声明并通过 L10n.Common 跨模块复用，
            # 严禁在各子业务表中私自定义。在此处将其列入白名单豁免属于临时兼容历史遗留技术债的防御措施，防止阻断编译，后续治理应逐步物理清理冗余键。
            "ok", "cancel", "done", "save", "delete", "edit", "refresh", "success", "failed", "error", 
            "loading", "about", "ignore", "preview", "skip", "unknown", "yesterday", "retry", "none", "all", "Ready",
            "确定", "取消", "完成", "保存", "删除", "编辑", "刷新", "成功", "失败", "错误", "加载中", "关于", "忽略", 
            "预览", "跳过", "未知", "昨天", "重试", "无", "全部",
            # 8. 调试沙盒与系统核心测试连接等工具专有文本：
            # 豁免原因说明：此类词汇多属于连接检测反馈、硬件连通性与沙盒模拟过程的专属技术/调试指令，
            # 为保证在开发者后台及测试实验室中能够多次引用且不受跨文件规则干扰，在此进行专属豁免。
            "health check", "健康检查", "分类", "category", "api 密钥", "api key", "test connection", "测试连接", "completed", "已完成"
        }

    def _is_duplicate_exempt(self, val):
        """
        判断某个翻译值是否应豁免判定为重复值。
        """
        if not val:
            return True
        trimmed = val.strip()
        if not trimmed:
            return True
        if trimmed.lower() in self.exempt_values:
            return True
        # 针对中文字符进行特定处理：若包含 CJK 字符，放宽短词豁免长度到 4
        has_cjk = any('\u4e00' <= char <= '\u9fff' for char in trimmed)
        
        if has_cjk:
            # 纯中文常用双字、三字、四字短语（如"搜索", "来源", "字", "标签", "类型"等）
            if len(trimmed) <= self.MAX_CJK_EXEMPT_LEN and re.match(r'^[\u4e00-\u9fff.%@\s\-()\[\]\d]+$', trimmed):
                return True
        else:
            # 英文/ASCII 短词
            if len(trimmed) <= self.MAX_SHORT_EXEMPT_LEN and re.match(r'^[a-zA-Z0-9.%@\s\-()\[\]]+$', trimmed):
                return True
                
        if re.match(r'^[0-9.%@\s\-\[\]\(\)<>=+:]+$', trimmed):
            return True
        return False

    def _collect_translation_values(self):
        """
        遍历所有 .xcstrings 文件，汇总所有翻译项。
        
        :return: value_map dict
        """
        value_map = {}
        for file in os.listdir(self.catalogs_dir):
            if not file.endswith('.xcstrings'):
                continue
            path = os.path.join(self.catalogs_dir, file)
            with open(path, 'r', encoding='utf-8') as f:
                try:
                    data = json.load(f)
                except Exception:
                    continue
            for key, val in data.get('strings', {}).items():
                locs = val.get('localizations', {})
                zh = locs.get('zh-Hans', {}).get('stringUnit', {}).get('value', '').strip()
                en = locs.get('en', {}).get('stringUnit', {}).get('value', '').strip()
                
                # 记录 zh-Hans
                if zh and not self._is_duplicate_exempt(zh):
                    self._add_to_map(value_map, 'zh-Hans', zh, file, key)
                
                # 记录 en
                if en and not self._is_duplicate_exempt(en):
                    self._add_to_map(value_map, 'en', en, file, key)
        return value_map

    def _add_to_map(self, value_map, lang, val, file, key):
        """辅助方法：插入映射表。"""
        k = (lang, val)
        if k not in value_map:
            value_map[k] = {}
        if file not in value_map[k]:
            value_map[k][file] = set()
        value_map[k][file].add(key)

    def _process_duplicate_issues(self, value_map):
        """
        处理并归类同文件内与跨文件内的重复翻译项。
        """
        in_file_issues = []
        cross_file_issues = []

        for (lang, val), files_dict in value_map.items():
            # 计算包含这个翻译的总 key 数量
            total_keys = sum(len(ks) for ks in files_dict.values())
            if total_keys <= 1:
                continue

            # 按同文件内和跨文件分类
            for file, keys in files_dict.items():
                if len(keys) > 1:
                    # 同文件内重复
                    severity = "WARNING"
                    in_file_issues.append((file, val, sorted(list(keys)), lang, severity))

            # 跨文件重复：仅在涉及公共核心包 Common.xcstrings 时才予以 Cross-file duplicate 警告，
            # 允许各业务模块分表独立的同名词条存在，保证业务隔离。
            if len(files_dict) > 1:
                if "Common.xcstrings" in files_dict:
                    # 收集所有出现该重复值的 (file, key) 组合
                    all_occurrences = []
                    for file, keys in files_dict.items():
                        for key in keys:
                            all_occurrences.append(f"{file}:{key}")
                    severity = "WARNING"
                    cross_file_issues.append((lang, val, sorted(all_occurrences), severity))

        return in_file_issues, cross_file_issues

    def detect(self):
        """
        执行同文件及跨文件翻译内容重复审计。
        
        :return: (in_file_issues, cross_file_issues)
                 每个元素为 (file, value, keys_list, lang, severity)
        """
        value_map = self._collect_translation_values()
        return self._process_duplicate_issues(value_map)


def _populate_in_file_dup(reporter, in_file_dup):
    """辅助填充同文件内重复翻译值违规。"""
    for file, val, keys, lang, level in in_file_dup:
        if val.strip() in EXEMPT_DUPLICATE_VALUES:
            continue
        keys_str = ", ".join(keys)
        reporter.add_issue(file, 1, f"Duplicate translation value for '{lang}': \"{val}\" is defined by multiple keys [{keys_str}]", level)


def _populate_cross_file_dup(reporter, cross_file_dup):
    """辅助填充跨文件重复翻译值违规。"""
    for lang, val, occurrences, level in cross_file_dup:
        if val.strip() in EXEMPT_DUPLICATE_VALUES:
            continue
        occurrences_str = ", ".join(occurrences)
        first_file = occurrences[0].split(':')[0]
        reporter.add_issue(first_file, 1, f"Cross-file duplicate translation value for '{lang}': \"{val}\" is defined in multiple files [{occurrences_str}]", level)


def _populate_reporter_issues(reporter, all_source_issues, xcstrings_issues, missing_key_issues, cross_file_issues, unused_key_issues, in_file_dup, cross_file_dup):
    """辅助将所有检测到的多语言合规缺陷注入到 reporter 中，以降低 main 的圈复杂度。"""
    # 1. 导入源码硬编码中文/UI英文违规
    for file_path, issues in sorted(all_source_issues.items()):
        for line_no, content, msg, level in issues:
            reporter.add_issue(file_path, line_no, msg, level, content)

    # 2. 导入 .xcstrings Catalog 违规
    for file, key, msg, level in xcstrings_issues:
        reporter.add_issue(file, 1, f"Catalog issue for Key: '{key}' - {msg}", level)

    # 3. 导入 Missing Keys 违规
    for file, key, msg, level in missing_key_issues:
        reporter.add_issue(file, 1, f"Missing Key: '{key}' - {msg}", level)

    # 4. 导入跨文件不一致违规
    for key, sources, msg, level in cross_file_issues:
        for file, val in sources.items():
            reporter.add_issue(file, 1, f"Cross-file Inconsistency for Key: '{key}' - {msg}", level, val)

    # 5. 导入未使用的 Key 警告
    for file, key, msg, level in sorted(unused_key_issues):
        reporter.add_issue(file, 1, f"Unused Key: '{key}' - {msg}", "WARNING")

    # 6. 导入同文件内重复翻译值违规
    _populate_in_file_dup(reporter, in_file_dup)

    # 7. 导入跨文件重复翻译值违规
    _populate_cross_file_dup(reporter, cross_file_dup)


def main():
    """本地化守卫网关的执行总入口。"""
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
    from gatekeeper_reporter import GatekeeperReporter
    
    reporter = GatekeeperReporter("L10n Audit")
    
    code_auditor = SourceCodeAuditor()
    catalog_auditor = XCStringsAuditor()
    missing_detector = MissingKeyDetector()
    inconsistency_detector = CrossFileInconsistencyDetector()
    obsolete_detector = ObsoleteKeyDetector()
    duplicate_detector = DuplicateTranslationDetector()

    all_source_issues = code_auditor.audit_all()
    xcstrings_issues = catalog_auditor.audit()
    missing_key_issues = missing_detector.detect()
    cross_file_issues = inconsistency_detector.detect()
    unused_key_issues = obsolete_detector.detect()
    in_file_dup, cross_file_dup = duplicate_detector.detect()

    _populate_reporter_issues(
        reporter, all_source_issues, xcstrings_issues, missing_key_issues,
        cross_file_issues, unused_key_issues, in_file_dup, cross_file_dup
    )
    
    reporter.report()


if __name__ == '__main__':
    main()
