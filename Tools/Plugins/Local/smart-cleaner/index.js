/**
 * Smart Cleaner — 智宇本地插件
 *
 * 功能：
 * 1. preProcess: 保存内容前自动清理冗余空行、规范化空格
 * 2. 工具栏按钮: 一键统计当前文档的清洗效果
 *
 * 安装：将本目录复制到 App 的 Documents/Plugins/ 下
 */

// ── 状态 ──
var stats = {
    totalRuns: 0,
    totalLinesRemoved: 0,
    lastRunTime: null
};

// ── 核心清洗逻辑 ──

/**
 * 清洗 Markdown 内容
 * - 合并 3 个以上连续空行为 2 个
 * - 去除行尾空格
 * - 去除文件首尾多余空行
 * - 统一换行为 \n
 */
function cleanContent(text) {
    if (!text || typeof text !== 'string') return text;

    var originalLines = text.split('\n').length;

    // 1. 统一换行符
    var cleaned = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    // 2. 去除行尾空格
    cleaned = cleaned.replace(/[ \t]+$/gm, '');

    // 3. 合并 3 个以上连续空行为 2 个
    cleaned = cleaned.replace(/\n{3,}/g, '\n\n');

    // 4. 去除文件首尾空行
    cleaned = cleaned.replace(/^\n+/, '').replace(/\n+$/, '');

    // 确保以换行结尾
    if (cleaned.length > 0 && !cleaned.endsWith('\n')) {
        cleaned += '\n';
    }

    var newLines = cleaned.split('\n').length;
    var removed = originalLines - newLines;

    // 更新统计
    stats.totalRuns++;
    if (removed > 0) {
        stats.totalLinesRemoved += removed;
    }
    stats.lastRunTime = new Date().toISOString();

    ZhiYu.log('[SmartCleaner] 清洗完成: 移除 ' + removed + ' 行, 累计清洗 ' + stats.totalRuns + ' 次');

    return cleaned;
}

// ── 工具栏回调 ──

function showStats() {
    var msg = '📊 Smart Cleaner 统计\n' +
              '累计运行: ' + stats.totalRuns + ' 次\n' +
              '累计移除: ' + stats.totalLinesRemoved + ' 行\n' +
              '最后运行: ' + (stats.lastRunTime || 'N/A');
    ZhiYu.log(msg);
}

// ── 生命周期 ──

function onLoad() {
    ZhiYu.log('[SmartCleaner] v1.0.0 已加载 — 自动清洗已激活');

    // 注册工具栏按钮，方便查看统计
    ZhiYu.registerRibbonItem('sparkles', '清洗统计', 'showStats');

    // 恢复持久化统计
    var saved = ZhiYu.loadData('stats');
    if (saved) {
        try {
            var parsed = JSON.parse(saved);
            stats = parsed;
            ZhiYu.log('[SmartCleaner] 已恢复历史统计');
        } catch (e) {
            ZhiYu.log('[SmartCleaner] 统计恢复失败，使用默认值');
        }
    }
}

function onUnload() {
    // 持久化统计
    ZhiYu.saveData('stats', JSON.stringify(stats));
    ZhiYu.log('[SmartCleaner] 已卸载，统计已保存');
}

// ── 内容拦截钩子 ──

function preProcess(content) {
    return cleanContent(content);
}

function postProcess(content) {
    // 后处理暂不做额外操作，直接返回
    return content;
}
