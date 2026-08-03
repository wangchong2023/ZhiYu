#!/bin/bash
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明:
# 本脚本用于在 CI/CD 流水线运行结束（成功、失败或状态发生变更）时，
# 通过 Webhook 机器人向指定的飞书群组发送通知卡片。
# 脚本会检测流水线状态变化，避免在状态未变化时进行重复的通知发送。
#

set -euo pipefail

STATUS="${CI_PIPELINE_STATUS:-unknown}"
HEALTH_FILE="build/.ci_health"

# 仅在失败或恢复时发送
LAST_STATUS="unknown"
[ -f "$HEALTH_FILE" ] && LAST_STATUS=$(head -1 "$HEALTH_FILE")
echo "$STATUS" > "$HEALTH_FILE"

if [ "$STATUS" = "$LAST_STATUS" ]; then
    echo "ℹ️  状态未变 ($STATUS)，跳过通知"
    exit 0
fi

WEBHOOK="${FEISHU_WEBHOOK_URL:-}"
if [ -z "$WEBHOOK" ]; then
    echo "⚠️  FEISHU_WEBHOOK_URL 未设置，跳过通知"
    exit 0
fi

SHA_SHORT="${CI_COMMIT_SHA:0:8}"
MSG="${CI_COMMIT_MESSAGE:-No message}"
PIPELINE_URL="${CI_PIPELINE_URL:-https://woodpecker.zhiyu.app}"

if [ "$STATUS" = "failure" ]; then
    EMOJI="🔴"
    TITLE="CI 流水线失败"
    COLOR="red"
else
    EMOJI="🟢"
    TITLE="CI 流水线已恢复"
    COLOR="green"
fi

JSON=$(cat << JSONEOF
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {"tag": "plain_text", "content": "$EMOJI $TITLE"},
      "template": "$COLOR"
    },
    "elements": [
      {"tag": "div", "text": {"tag": "lark_md", "content": "**提交:** $SHA_SHORT — $MSG"}},
      {"tag": "div", "text": {"tag": "lark_md", "content": "**流水线:** #$CI_PIPELINE_NUMBER"}},
      {"tag": "action", "actions": [{"tag": "button", "text": {"tag": "plain_text", "content": "查看日志"}, "url": "$PIPELINE_URL", "type": "default"}]}
    ]
  }
}
JSONEOF
)

curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$WEBHOOK"
echo ""
echo "  ✅ 飞书通知已发送 ($STATUS)"
