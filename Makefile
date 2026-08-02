# Makefile — 智宇 (ZhiYu) 极简构建与自动化工具集
#
# 自动强载 Config/.env.local 环境变量，无需手动输入 source
-include Config/.env.local
export

.PHONY: all gen bootstrap ios mac watch test test-spm test-spm-all test-all audit lint help

help:
	@echo "智宇 (ZhiYu) 快捷构建与自动化命令列表："
	@echo "  make gen               - 运行 bootstrap 初始化环境并重新生成 ZhiYu.xcodeproj"
	@echo "  make ios               - 构建 iOS Scheme"
	@echo "  make mac               - 构建 macOS Catalyst Scheme"
	@echo "  make watch             - 构建 watchOS Scheme"
	@echo "  make test              - 运行主 App 单元测试"
	@echo "  make test-spm PKG=包名  - 运行指定 SPM 本地包极速单测 (例: make test-spm PKG=UFPStorage)"
	@echo "  make test-spm-all      - 运行所有 SPM 本地包极速单测 (UFPCore/Storage/DesignSystem/Domain/AICore/Features)"
	@echo "  make test-all          - 运行全量 SPM 包单测 + 主 App 单元测试"
	@echo "  make audit             - 运行 8 大 Gatekeeper 静态架构与依赖审计"
	@echo "  make lint              - 运行 SwiftLint 严格代码校验"

gen: bootstrap

bootstrap:
	@echo "⚙️  自动加载 Config/.env.local 并重生成 Xcode 项目..."
	@bash Tools/Utils/bootstrap.sh

ios: gen
	@echo "📱 正在构建 iOS Targets..."
	@xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

mac: gen
	@echo "💻 正在构建 macOS Catalyst Targets..."
	@xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

watch: gen
	@echo "⌚️ 正在构建 watchOS Targets..."
	@xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test: gen
	@echo "🧪 运行主 App 单元测试..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-spm:
	@if [ -z "$(PKG)" ]; then \
		echo "❌ 请指定 PKG 参数，例如: make test-spm PKG=UFPStorage"; \
		exit 1; \
	fi
	@echo "⚡️ 正在极速单测 Packages/$(PKG) ..."
	@swift test --package-path Packages/$(PKG)

test-spm-all:
	@echo "⚡️ 运行全量 SPM 本地包极速单测套件..."
	@for pkg in UFPCore UFPStorage UFPDesignSystem ZhiYuDomain ZhiYuAICore ZhiYuFeatures; do \
		echo "🧪 正在测试 Packages/$$pkg ..."; \
		swift test --package-path Packages/$$pkg || exit 1; \
	done
	@echo "✅ 所有 SPM 本地包单测全部通过！"

test-all: test-spm-all test

audit:
	@echo "🔍 运行 CI 架构与开源依赖门禁体系..."
	@python3 Tools/Gatekeeper/Architecture/check_opensource_adapters.py
	@python3 Tools/Gatekeeper/Architecture/check_dependency_registry.py
	@python3 Tools/Gatekeeper/Sanity/check_absolute_paths.py

lint:
	@swiftlint --strict
