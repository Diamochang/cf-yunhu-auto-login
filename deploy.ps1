Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  云湖自动登录 - 快速部署向导" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否已安装必要工具
Write-Host "[INFO] 检查依赖..." -ForegroundColor Yellow

try {
    $nodeVersion = node --version
    $npmVersion = npm --version
    Write-Host "[OK] Node.js 已安装: $nodeVersion" -ForegroundColor Green
    Write-Host "[OK] npm 已安装: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 未找到 Node.js 或 npm，请先安装 Node.js" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

Write-Host ""

# 检查是否已登录 Wrangler 或设置了 API Token
Write-Host "[INFO] 检查 Cloudflare 认证状态..." -ForegroundColor Yellow

if ($env:CLOUDFLARE_API_TOKEN -and $env:CLOUDFLARE_ACCOUNT_ID) {
    Write-Host "[OK] 使用环境变量进行认证 (CI/CD 模式)" -ForegroundColor Green
} else {
    try {
        npx wrangler whoami | Out-Null
        Write-Host "[OK] 已通过 wrangler login 认证" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] 未检测到认证信息，请选择认证方式:" -ForegroundColor Yellow
        Write-Host "  1. 使用 wrangler login (交互式)" -ForegroundColor White
        Write-Host "  2. 设置 CLOUDFLARE_API_TOKEN 和 CLOUDFLARE_ACCOUNT_ID 环境变量" -ForegroundColor White
        Write-Host "  3. 跳过认证检查 (不推荐)" -ForegroundColor White
        Write-Host ""
        
        $auth_choice = Read-Host "请选择 (1-3, 默认: 1)"
        
        switch ($auth_choice) {
            "2" {
                Write-Host "请设置以下环境变量后重新运行脚本:" -ForegroundColor Yellow
                Write-Host "  `$env:CLOUDFLARE_API_TOKEN='your_api_token'" -ForegroundColor White
                Write-Host "  `$env:CLOUDFLARE_ACCOUNT_ID='your_account_id'" -ForegroundColor White
                Read-Host "按回车键退出"
                exit 1
            }
            "3" {
                Write-Host "[WARN] 跳过认证检查" -ForegroundColor Yellow
            }
            default {
                Write-Host "正在启动 wrangler login..." -ForegroundColor Yellow
                npx wrangler login
            }
        }
    }
}

Write-Host ""

# 获取账号配置
Write-Host "配置账号信息" -ForegroundColor Yellow
Write-Host ""
Write-Host "请输入账号配置（JSON 数组格式）" -ForegroundColor White
Write-Host "示例：" -ForegroundColor White
Write-Host '[{"userId":"user1","token":"token1","platform":"windows"}]' -ForegroundColor Gray
Write-Host ""
Write-Host "你可以：" -ForegroundColor White
Write-Host "  1. 直接粘贴 JSON 数组" -ForegroundColor White
Write-Host "  2. 输入 'file' 从文件读取" -ForegroundColor White
Write-Host "  3. 输入 'skip' 稍后手动配置" -ForegroundColor White
Write-Host ""

$config_choice = Read-Host "请选择 (直接粘贴/file/skip)"

$ACCOUNT_CONFIGS = ""

switch ($config_choice) {
    "file" {
        $config_file = Read-Host "请输入配置文件路径"
        if (Test-Path $config_file) {
            $ACCOUNT_CONFIGS = Get-Content $config_file -Raw
            Write-Host "[OK] 已从文件读取配置" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] 文件不存在: $config_file" -ForegroundColor Red
            Read-Host "按回车键退出"
            exit 1
        }
    }
    "skip" {
        Write-Host "[WARN] 跳过配置，你需要稍后手动设置" -ForegroundColor Yellow
        $ACCOUNT_CONFIGS = "[]"
    }
    default {
        $ACCOUNT_CONFIGS = $config_choice
    }
}

Write-Host ""

# 验证 JSON 格式
if ($ACCOUNT_CONFIGS -ne "[]" -and $ACCOUNT_CONFIGS -ne "") {
    try {
        $jsonObj = $ACCOUNT_CONFIGS | ConvertFrom-Json
        Write-Host "[OK] JSON 格式验证通过" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] JSON 格式可能不正确，请检查输入" -ForegroundColor Yellow
        $continue_choice = Read-Host "是否继续？(y/n)"
        if ($continue_choice -ne "y" -and $continue_choice -ne "Y") {
            Write-Host "[ERROR] 部署已取消" -ForegroundColor Red
            Read-Host "按回车键退出"
            exit 0
        }
    }
}

# 获取 WebSocket URL
Write-Host "配置 WebSocket 服务器地址" -ForegroundColor Yellow
$websocket_url = Read-Host "WebSocket URL (默认: wss://chat-ws-go.jwzhd.com/ws)"
if ([string]::IsNullOrWhiteSpace($websocket_url)) {
    $websocket_url = "wss://chat-ws-go.jwzhd.com/ws"
}
Write-Host ""

# 选择配置方式（环境变量或 Secrets）
Write-Host "选择配置存储方式" -ForegroundColor Yellow
Write-Host "  1. 使用环境变量 (vars) - 配置保存在 wrangler.jsonc 中" -ForegroundColor White
Write-Host "  2. 使用 Secrets - 配置加密存储在 Cloudflare，更安全" -ForegroundColor White
Write-Host ""

$storage_choice = Read-Host "请选择 (1-2, 默认: 2)"

if ([string]::IsNullOrWhiteSpace($storage_choice)) {
    $storage_choice = "2"
}

$USE_VARS = $false
if ($storage_choice -eq "1") {
    $USE_VARS = $true
    Write-Host "[OK] 将使用环境变量 (vars) 方式" -ForegroundColor Green
} else {
    Write-Host "[OK] 将使用 Secrets 方式" -ForegroundColor Green
}

Write-Host ""

# 获取 Cron 表达式
Write-Host "配置定时触发器" -ForegroundColor Yellow
Write-Host "常用选项：" -ForegroundColor White
Write-Host "  1. 每30分钟 (*/30 * * * *)" -ForegroundColor White
Write-Host "  2. 每小时 (0 * * * *)" -ForegroundColor White
Write-Host "  3. 每4小时 (0 */4 * * *) - 推荐" -ForegroundColor White
Write-Host "  4. 每天 (0 0 * * *)" -ForegroundColor White
Write-Host "  5. 自定义" -ForegroundColor White
Write-Host ""

$cron_choice = Read-Host "请选择 (1-5, 默认: 3)"

$CRONExpression = ""

switch ($cron_choice) {
    "1" { $CRONExpression = "*/30 * * * *" }
    "2" { $CRONExpression = "0 * * * *" }
    "4" { $CRONExpression = "0 0 * * *" }
    "5" { $CRONExpression = Read-Host "请输入 Cron 表达式" }
    default { $CRONExpression = "0 */4 * * *" }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  配置汇总" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host " 账号配置: $ACCOUNT_CONFIGS" -ForegroundColor White
Write-Host " WebSocket URL: $websocket_url" -ForegroundColor White
Write-Host " Cron 表达式: $CRONExpression" -ForegroundColor White
Write-Host ""

# 当使用 Secrets 存储时，提示不可直接修改
if (-not $USE_VARS) {
    Write-Host " 注意：您选择了使用 Secrets 存储账号信息。" -ForegroundColor Yellow
    Write-Host "   Secrets 一旦设置后不能直接修改，只能删除后重新创建变量。" -ForegroundColor Yellow
    Write-Host "   如需修改账号配置，请先执行以下命令删除现有 Secret：" -ForegroundColor Yellow
    Write-Host "     npx wrangler secret delete ACCOUNT_CONFIGS" -ForegroundColor White
    Write-Host "   然后重新运行本脚本或使用 'npx wrangler secret put ACCOUNT_CONFIGS' 设置新值。" -ForegroundColor Yellow
    Write-Host ""
}

$confirm = Read-Host "确认部署？(y/n)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "[ERROR] 部署已取消" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 0
}

Write-Host ""
Write-Host "[INFO] 开始部署..." -ForegroundColor Yellow
Write-Host ""

# 生成 wrangler.jsonc 配置文件
Write-Host "[INFO] 生成 wrangler.jsonc 配置文件..." -ForegroundColor Yellow

try {
    # 复制模板文件
    Copy-Item "wrangler.example.jsonc" "wrangler.jsonc" -Force
    
    # 读取 wrangler.jsonc 文件
    $wranglerConfig = Get-Content "wrangler.jsonc" -Raw
    
    # 更新 Cron 表达式
    $pattern = '"crons"\s*:\s*\[[^\]]*\]'
    $replacement = "`"crons`": [`"$CRONExpression`"]"
    $wranglerConfig = $wranglerConfig -replace $pattern, $replacement
    
    # 根据选择处理 vars 部分
    if ($USE_VARS) {
        # 使用环境变量方式：更新 vars 中的值
        Write-Host "[INFO] 更新 vars 配置..." -ForegroundColor Yellow
        
        # 转义 JSON 字符串中的特殊字符
        $escapedAccountConfigs = $ACCOUNT_CONFIGS -replace '\\', '\\\\' -replace '"', '\\"'
        $escapedWebsocketUrl = $websocket_url -replace '\\', '\\\\' -replace '"', '\\"'
        
        # 替换 ACCOUNT_CONFIGS
        $pattern = '"ACCOUNT_CONFIGS"\s*:\s*"[^"]*"'
        $replacement = "`"ACCOUNT_CONFIGS`": `"$escapedAccountConfigs`""
        $wranglerConfig = $wranglerConfig -replace $pattern, $replacement
        
        # 替换 WEBSOCKET_URL
        $pattern = '"WEBSOCKET_URL"\s*:\s*"[^"]*"'
        $replacement = "`"WEBSOCKET_URL`": `"$escapedWebsocketUrl`""
        $wranglerConfig = $wranglerConfig -replace $pattern, $replacement
        
        Write-Host "[OK] vars 配置已更新" -ForegroundColor Green
    } else {
        # 使用 Secrets 方式：删除 vars 部分
        Write-Host "[INFO] 删除 vars 配置（将使用 Secrets）..." -ForegroundColor Yellow
        
        # 使用多行正则表达式精确删除从注释到 vars 闭合的部分
        # (?s) 启用单行模式，让 . 匹配换行符
        $pattern = '(?s)[\t ]*// 账号配置[^
]*
?
[\t ]*// 示例:[^
]*
?
[\t ]*// platform[^
]*
?
[\t ]*// deviceId[^
]*
?
[\t ]*"vars"[\t ]*:[\t ]*\{[^
]*
?
[\t ]*"ACCOUNT_CONFIGS"[^
]*
?
[\t ]*"WEBSOCKET_URL"[^
]*
?
[\t ]*\},'
        $wranglerConfig = $wranglerConfig -replace $pattern, ""
        
        Write-Host "[OK] vars 配置已删除" -ForegroundColor Green
    }
    
    # 写回文件
    Set-Content "wrangler.jsonc" $wranglerConfig -NoNewline
    Write-Host "[OK] wrangler.jsonc 配置文件已生成" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 生成 wrangler.jsonc 失败: $_" -ForegroundColor Red
    Read-Host "按回车键退出"
    exit 1
}

# 如果使用 Secrets 方式，设置秘密变量
if (-not $USE_VARS) {
    Write-Host ""
    Write-Host "[INFO] 设置 Secrets..." -ForegroundColor Yellow
    
    if ($ACCOUNT_CONFIGS -ne "[]") {
        try {
            $ACCOUNT_CONFIGS | npx wrangler secret put ACCOUNT_CONFIGS
            Write-Host "[OK] ACCOUNT_CONFIGS Secret 已设置" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] 设置 ACCOUNT_CONFIGS 失败: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[WARN] ACCOUNT_CONFIGS 为空，跳过设置" -ForegroundColor Yellow
    }
    
    if ($websocket_url -ne "wss://chat-ws-go.jwzhd.com/ws") {
        try {
            $websocket_url | npx wrangler secret put WEBSOCKET_URL
            Write-Host "[OK] WEBSOCKET_URL Secret 已设置" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] 设置 WEBSOCKET_URL 失败: $_" -ForegroundColor Red
        }
    }
}

# 部署
Write-Host ""
Write-Host "[INFO] 部署到 Cloudflare..." -ForegroundColor Yellow

# 检查是否需要安装依赖
if (-not (Test-Path "node_modules")) {
    Write-Host "[INFO] 安装依赖..." -ForegroundColor Yellow
    npm install
}

# 执行部署
npm run deploy

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  部署成功！" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " 查看日志:" -ForegroundColor Yellow
Write-Host "   npx wrangler tail" -ForegroundColor White
Write-Host ""
Write-Host " 修改配置:" -ForegroundColor Yellow
Write-Host "   npx wrangler secret put ACCOUNT_CONFIGS" -ForegroundColor White
Write-Host "   npx wrangler secret put WEBSOCKET_URL" -ForegroundColor White
Write-Host ""
Write-Host " 更多信息请查看 README.md" -ForegroundColor Yellow
Write-Host ""

Read-Host "按回车键退出"