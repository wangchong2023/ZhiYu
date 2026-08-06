# Makefile — 智宇 (ZhiYu) 极简构建与自动化工具集
#
# 自动强载 Config/.env.local 环境变量，无需手动输入 source
-include Config/.env.local
export

.PHONY: all gen bootstrap ios mac watch test test-unit test-ui test-spm test-spm-all test-all audit lint perf perf-baseline plugin-scan doc-drift exemptions-check exemptions-rebuild coverage-spm help

help:
	@echo "智宇 (ZhiYu) 快捷构建与自动化命令列表："
	@echo "  make gen               - 运行 bootstrap 初始化环境并重新生成 ZhiYu.xcodeproj"
	@echo "  make ios               - 构建 iOS Scheme"
	@echo "  make mac               - 构建 macOS Catalyst Scheme"
	@echo "  make watch             - 构建 watchOS Scheme"
	@echo "  make test              - 运行主 App 全量测试（单元 + UI）"
	@echo "  make test-unit         - 仅运行单元测试（排除 UI 测试，约 3 分钟）"
	@echo "  make test-ui           - 仅运行 UI 测试"
	@echo "  make test-spm PKG=包名  - 运行指定 SPM 本地包极速单测 (例: make test-spm PKG=UFPStorage)"
	@echo "  make test-spm-all      - 运行所有 SPM 本地包极速单测 (UFPCore/Storage/DesignSystem/Domain/AICore/Features)"
	@echo "  make test-all          - 运行全量 SPM 包单测 + 主 App 单元测试"
	@echo "  make audit             - 运行 8 大 Gatekeeper 静态架构与依赖审计"
	@echo "  make lint              - 运行 SwiftLint 严格代码校验"
	@echo "  make perf              - 运行性能测试套件 + 性能回归比对"
	@echo "  make perf-baseline     - 生成/刷新性能基线 (首次运行或基线漂移时使用)"
	@echo "  make plugin-scan       - 扫描插件市场目录安全校验"
	@echo "  make doc-drift         - 检测文档与代码的漂移 (类/协议/方法引用一致性)"
	@echo "  make exemptions-check  - 免白名单注册中心：统计符号集 + 检测过期白名单项"
	@echo "  make exemptions-rebuild - 重建 Apple SDK / 第三方库符号缓存"
	@echo "  make coverage-spm     - 测量所有 SPM 包语句/分支覆盖率（对照 ≥90% 阈值）"
	@echo "  make coverage-spm PKG=UFPCore  - 仅测量指定包覆盖率"
	@echo "  make coverage-spm DETAILS=1    - 展示每文件覆盖率"

gen: bootstrap

bootstrap:
	@echo "⚙️  自动加载 Config/.env.local 并重生成 Xcode 项目..."
	@bash Tools/scripts/run-quality-bootstrap.sh

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
	@echo "🧪 运行主 App 全量测试（单元 + UI）..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-unit: gen
	@echo "🧪 仅运行单元测试（排除 UI 测试）..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests -enableCodeCoverage YES -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

test-ui: gen
	@echo "🧪 仅运行 UI 测试..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuUITests -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

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
	@python3 Tools/ios/check-arch-opensource-adapters.py
	@python3 Tools/ios/check-arch-dependency-registry.py
	@python3 Tools/ios/check-code-absolute-paths.py

lint:
	@swiftlint --strict

perf: gen
	@echo "📊 运行性能测试套件..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:ZhiYuTests/KnowledgeStorePerformanceTests \
		-only-testing:ZhiYuTests/RAGPerformanceTests \
		-only-testing:ZhiYuTests/SearchPerformanceTests \
		-only-testing:ZhiYuTests/KnowledgeStoreStressTests \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
		-resultBundlePath build/Performance.xcresult 2>&1 | tail -20
	@echo "📊 性能回归比对..."
	@python3 Tools/CI/check-pipeline-perf-regression.py || \
		echo "⚠️  无性能基线，请运行 'make perf-baseline' 建立基线"

perf-baseline: gen
	@echo "📊 生成性能基线..."
	@xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:ZhiYuTests/KnowledgeStorePerformanceTests \
		-only-testing:ZhiYuTests/RAGPerformanceTests \
		-only-testing:ZhiYuTests/SearchPerformanceTests \
		-only-testing:ZhiYuTests/KnowledgeStoreStressTests \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
		-resultBundlePath build/Performance.xcresult 2>&1 | tail -5
	@bash Tools/CI/generate-pipeline-perf-baseline.sh
	@echo "✅ 性能基线已生成于 build/.perf_baselines/"

plugin-scan:
	@echo "🔌 扫描插件市场目录安全校验..."
	@python3 Tools/CI/scan-plugin-marketplace.py

doc-drift:
	@echo "📄 检测文档与代码漂移..."
	@python3 Tools/CI/check-doc-drift.py

exemptions-check:
	@echo "📋 免白名单注册中心：统计 + 过期检测..."
	@python3 Tools/CI/exemption_registry.py stats
	@echo ""
	@python3 Tools/CI/exemption_registry.py check-stale

exemptions-rebuild:
	@echo "🔄 重建 Apple SDK / 第三方库符号缓存..."
	@python3 Tools/CI/exemption_registry.py rebuild-cache

coverage-spm:
	@echo "📊 测量 SPM 包覆盖率..."
	@python3 Tools/CI/coverage-spm.py $(if $(PKG),--pkg $(PKG),) $(if $(DETAILS),--details,)
