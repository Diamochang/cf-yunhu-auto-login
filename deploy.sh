#!/bin/bash

# 云呼自动登录 - 快速部署脚本
# 此脚本帮助你快速配置和部署 Worker

set -e

echo "======================================"
echo "  云呼自动登录 - 快速部署向导"
echo "======================================"
echo ""

# 检查是否已安装必要工具
echo "📋 检查依赖..."

if ! command -v node &> /dev/null; then
    echo "❌ 未找到 Node.js，请先安装 Node.js"
    exit 1
fi

if ! command -v npx &> /dev/null; then
    echo "❌ 未找到 npx，请确保 npm 已正确安装"
    exit 1
fi

echo "✅ Node.js 已安装: $(node --version)"
echo "✅ npm 已安装: $(npm --version)"
echo ""

# 检查是否已登录 Wrangler
echo "🔐 检查 Cloudflare 登录状态..."
if ! npx wrangler whoami &> /dev/null; then
    echo "⚠️  未登录 Cloudflare，正在启动登录流程..."
    npx wrangler login
else
    echo "✅ 已登录 Cloudflare"
fi
echo ""

# 获取账号配置
echo "📝 配置账号信息"
echo ""
echo "请输入账号配置（JSON 数组格式）"
echo "示例："
echo '[{"userId":"user1","token":"token1","platform":"windows"}]'
echo ""
echo "你可以："
echo "  1. 直接粘贴 JSON 数组"
echo "  2. 输入 'file' 从文件读取"
echo "  3. 输入 'skip' 稍后手动配置"
echo ""
read -p "请选择 (直接粘贴/file/skip): " config_choice

ACCOUNT_CONFIGS=""

case $config_choice in
    file)
        read -p "请输入配置文件路径: " config_file
        if [ -f "$config_file" ]; then
            ACCOUNT_CONFIGS=$(cat "$config_file")
            echo "✅ 已从文件读取配置"
        else
            echo "❌ 文件不存在: $config_file"
            exit 1
        fi
        ;;
    skip)
        echo "⚠️  跳过配置，你需要稍后手动设置"
        ACCOUNT_CONFIGS="[]"
        ;;
    *)
        ACCOUNT_CONFIGS="$config_choice"
        ;;
esac

echo ""

# 获取 WebSocket URL
echo "🌐 配置 WebSocket 服务器地址"
read -p "WebSocket URL (默认: wss://chat-ws-go.jwzhd.com/ws): " websocket_url
if [ -z "$websocket_url" ]; then
    websocket_url="wss://chat-ws-go.jwzhd.com/ws"
fi
echo ""

# 获取 Cron 表达式
echo "⏰ 配置定时触发器"
echo "常用选项："
echo "  1. 每30分钟 (*/30 * * * *) - 推荐"
echo "  2. 每小时 (0 * * * *)"
echo "  3. 每6小时 (0 */6 * * *)"
echo "  4. 每天 (0 0 * * *)"
echo "  5. 自定义"
echo ""
read -p "请选择 (1-5, 默认: 1): " cron_choice

case $cron_choice in
    2)
        CRONExpression="0 * * * *"
        ;;
    3)
        CRONExpression="0 */6 * * *"
        ;;
    4)
        CRONExpression="0 0 * * *"
        ;;
    5)
        read -p "请输入 Cron 表达式: " CRONExpression
        ;;
    *)
        CRONExpression="*/30 * * * *"
        ;;
esac

echo ""
echo "======================================"
echo "  配置汇总"
echo "======================================"
echo "账号配置: $ACCOUNT_CONFIGS"
echo "WebSocket URL: $websocket_url"
echo "Cron 表达式: $CRONExpression"
echo ""
read -p "确认部署？(y/n): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ 部署已取消"
    exit 0
fi

echo ""
echo "🚀 开始部署..."
echo ""

# 更新 wrangler.jsonc 中的 Cron 表达式
echo "📝 更新 Cron 配置..."
# 使用 | 作为分隔符避免与 Cron 表达式中的 / 冲突
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|\"crons\": \[.*\]|\"crons\": [\"$CRONExpression\"]|" wrangler.jsonc
else
    # Linux
    sed -i "s|\"crons\": \[.*\]|\"crons\": [\"$CRONExpression\"]|" wrangler.jsonc
fi
echo "✅ Cron 配置已更新"

# 设置秘密变量
echo ""
echo "🔐 设置秘密变量..."

if [ "$ACCOUNT_CONFIGS" != "[]" ]; then
    echo "$ACCOUNT_CONFIGS" | npx wrangler secret put ACCOUNT_CONFIGS
    echo "✅ ACCOUNT_CONFIGS 已设置"
else
    echo "⚠️  使用 wrangler.jsonc 中的默认配置"
fi

if [ "$websocket_url" != "wss://chat-ws-go.jwzhd.com/ws" ]; then
    echo "$websocket_url" | npx wrangler secret put WEBSOCKET_URL
    echo "✅ WEBSOCKET_URL 已设置"
fi

# 部署
echo ""
echo "📦 部署到 Cloudflare..."
npm run deploy

echo ""
echo "======================================"
echo "  ✅ 部署成功！"
echo "======================================"
echo ""
echo "📊 查看日志:"
echo "   npx wrangler tail"
echo ""
echo "🔧 修改配置:"
echo "   npx wrangler secret put ACCOUNT_CONFIGS"
echo ""
echo "📖 更多信息请查看 README.md"
echo ""
