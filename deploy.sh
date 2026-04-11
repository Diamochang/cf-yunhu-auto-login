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

# 检查是否已登录 Wrangler 或设置了 API Token
echo "🔐 检查 Cloudflare 认证状态..."
if [ -n "$CLOUDFLARE_API_TOKEN" ] && [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo "✅ 使用环境变量进行认证 (CI/CD 模式)"
elif npx wrangler whoami &> /dev/null; then
    echo "✅ 已通过 wrangler login 认证"
else
    echo "⚠️  未检测到认证信息，请选择认证方式:"
    echo "  1. 使用 wrangler login (交互式)"
    echo "  2. 设置 CLOUDFLARE_API_TOKEN 和 CLOUDFLARE_ACCOUNT_ID 环境变量"
    echo "  3. 跳过认证检查 (不推荐)"
    echo ""
    read -p "请选择 (1-3, 默认: 1): " auth_choice
    
    case $auth_choice in
        2)
            echo "请设置以下环境变量后重新运行脚本:"
            echo "  export CLOUDFLARE_API_TOKEN='your_api_token'"
            echo "  export CLOUDFLARE_ACCOUNT_ID='your_account_id'"
            exit 1
            ;;
        3)
            echo "⚠️  跳过认证检查"
            ;;
        *)
            echo "正在启动 wrangler login..."
            npx wrangler login
            ;;
    esac
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

# 验证 JSON 格式
if [ "$ACCOUNT_CONFIGS" != "[]" ] && [ -n "$ACCOUNT_CONFIGS" ]; then
    if ! echo "$ACCOUNT_CONFIGS" | python3 -m json.tool &> /dev/null; then
        echo "⚠️  JSON 格式可能不正确，请检查输入"
        read -p "是否继续？(y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            echo "❌ 部署已取消"
            exit 0
        fi
    fi
fi

# 获取 WebSocket URL
echo "🌐 配置 WebSocket 服务器地址"
read -p "WebSocket URL (默认: wss://chat-ws-go.jwzhd.com/ws): " websocket_url
if [ -z "$websocket_url" ]; then
    websocket_url="wss://chat-ws-go.jwzhd.com/ws"
fi
echo ""

# 选择配置方式（环境变量或 Secrets）
echo "🔧 选择配置存储方式"
echo "  1. 使用环境变量 (vars) - 配置保存在 wrangler.jsonc 中"
echo "  2. 使用 Secrets - 配置加密存储在 Cloudflare，更安全"
echo ""
read -p "请选择 (1-2, 默认: 2): " storage_choice

if [ -z "$storage_choice" ]; then
    storage_choice="2"
fi

USE_VARS=false
if [ "$storage_choice" = "1" ]; then
    USE_VARS=true
    echo "✅ 将使用环境变量 (vars) 方式"
else
    echo "✅ 将使用 Secrets 方式"
fi
echo ""

# 获取 Cron 表达式
echo "⏰ 配置定时触发器"
echo "常用选项："
echo "  1. 每30分钟 (*/30 * * * *)"
echo "  2. 每小时 (0 * * * *)"
echo "  3. 每4小时 (0 */4 * * *) - 推荐"
echo "  4. 每天 (0 0 * * *)"
echo "  5. 自定义"
echo ""
read -p "请选择 (1-5, 默认: 3): " cron_choice

case $cron_choice in
    1)
        CRONExpression="*/30 * * * *"
        ;;
    2)
        CRONExpression="0 * * * *"
        ;;
    4)
        CRONExpression="0 0 * * *"
        ;;
    5)
        read -p "请输入 Cron 表达式: " CRONExpression
        ;;
    *)
        CRONExpression="0 */4 * * *"
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

# 生成 wrangler.jsonc 配置文件
echo "📝 生成 wrangler.jsonc 配置文件..."

# 复制模板文件
cp wrangler.example.jsonc wrangler.jsonc

# 更新 Cron 表达式
# 使用 | 作为分隔符避免与 Cron 表达式中的 / 冲突
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|\"crons\": \[.*\]|\"crons\": [\"$CRONExpression\"]|" wrangler.jsonc
else
    # Linux
    sed -i "s|\"crons\": \[.*\]|\"crons\": [\"$CRONExpression\"]|" wrangler.jsonc
fi

# 根据选择处理 vars 部分
if [ "$USE_VARS" = true ]; then
    # 使用环境变量方式：更新 vars 中的值
    echo "📝 更新 vars 配置..."
    
    # 转义特殊字符用于 sed
    escaped_account_configs=$(echo "$ACCOUNT_CONFIGS" | sed 's/[&/\\]/\\&/g')
    escaped_websocket_url=$(echo "$websocket_url" | sed 's/[&/\\]/\\&/g')
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|\"ACCOUNT_CONFIGS\": \"[^\"]*\"|\"ACCOUNT_CONFIGS\": \"$escaped_account_configs\"|" wrangler.jsonc
        sed -i '' "s|\"WEBSOCKET_URL\": \"[^\"]*\"|\"WEBSOCKET_URL\": \"$escaped_websocket_url\"|" wrangler.jsonc
    else
        # Linux
        sed -i "s|\"ACCOUNT_CONFIGS\": \"[^\"]*\"|\"ACCOUNT_CONFIGS\": \"$escaped_account_configs\"|" wrangler.jsonc
        sed -i "s|\"WEBSOCKET_URL\": \"[^\"]*\"|\"WEBSOCKET_URL\": \"$escaped_websocket_url\"|" wrangler.jsonc
    fi
    
    echo "✅ vars 配置已更新"
else
    # 使用 Secrets 方式：删除 vars 部分（第 39-46 行）
    echo "📝 删除 vars 配置（将使用 Secrets）..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - 使用 awk 精确删除从注释到 vars 闭合的部分
        awk '
        /\/\/ 账号配置/ { skip=1; next }
        skip && /^[[:space:]]*\},$/ { skip=0; next }
        !skip { print }
        ' wrangler.jsonc > wrangler.jsonc.tmp && mv wrangler.jsonc.tmp wrangler.jsonc
    else
        # Linux - 使用 awk 精确删除从注释到 vars 闭合的部分
        awk '
        /\/\/ 账号配置/ { skip=1; next }
        skip && /^[[:space:]]*\},$/ { skip=0; next }
        !skip { print }
        ' wrangler.jsonc > wrangler.jsonc.tmp && mv wrangler.jsonc.tmp wrangler.jsonc
    fi
    
    echo "✅ vars 配置已删除"
fi

echo "✅ wrangler.jsonc 配置文件已生成"

# 如果使用 Secrets 方式，设置秘密变量
if [ "$USE_VARS" = false ]; then
    echo ""
    echo "🔐 设置 Secrets..."
    
    if [ "$ACCOUNT_CONFIGS" != "[]" ]; then
        echo "$ACCOUNT_CONFIGS" | npx wrangler secret put ACCOUNT_CONFIGS
        echo "✅ ACCOUNT_CONFIGS Secret 已设置"
    else
        echo "⚠️  ACCOUNT_CONFIGS 为空，跳过设置"
    fi
    
    if [ "$websocket_url" != "wss://chat-ws-go.jwzhd.com/ws" ]; then
        echo "$websocket_url" | npx wrangler secret put WEBSOCKET_URL
        echo "✅ WEBSOCKET_URL Secret 已设置"
    fi
fi

# 部署
echo ""
echo "📦 部署到 Cloudflare..."

# 检查是否需要安装依赖
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
fi

# 执行部署
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
echo "   npx wrangler secret put WEBSOCKET_URL"
echo ""
echo "📖 更多信息请查看 README.md"
echo ""
