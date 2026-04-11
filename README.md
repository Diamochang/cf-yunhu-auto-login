# 云湖自动登录 Cloudflare Workers 版

这是一个基于 Cloudflare Workers 的云湖定时自动登录脚本，用于定期向云湖 WebSocket 服务器发送登录请求以保持账号连续在线状态。

## 功能特性

- ✅ 支持多账号配置
- ✅ 定时自动执行（默认每 4 小时）
- ✅ 自动生成设备 ID
- ✅ 支持多种平台类型（Windows、Android、iOS、MacOS、Web、Linux、HarmonyOS）
- ✅ 详细的日志输出
- ✅ 错误处理和重试机制

## 配置说明

### 1. 配置存储方式

本项目支持两种配置存储方式，您可以根据需求选择：

#### 方式 A：使用环境变量 (vars) - 适合开发环境
- ✅ 配置保存在 `wrangler.jsonc` 文件中
- ✅ 便于测试
- ⚠️ 配置以明文形式存储在 Worker 中

#### 方式 B：使用 Secrets - 适合生产环境（推荐）
- ✅ 配置加密存储在 Cloudflare
- ✅ 不会明文存储在 Worker 中
- ✅ 更安全，适合敏感信息

### 2. 环境变量配置

根据选择的存储方式，配置方法有所不同：

#### 如果使用环境变量 (vars)

在 `wrangler.jsonc` 文件的 `vars` 部分配置：

```json
"vars": {
  "ACCOUNT_CONFIGS": "[{\"userId\":\"user1\",\"token\":\"token1\",\"platform\":\"linux\"}]",
  "WEBSOCKET_URL": "wss://chat-ws-go.jwzhd.com/ws"
}
```

#### 如果使用 Secrets

通过 Wrangler CLI 设置加密的秘密变量：

```bash
# 设置账号配置
npx wrangler secret put ACCOUNT_CONFIGS
# 粘贴 JSON 格式的账号配置

# 设置 WebSocket URL（可选）
npx wrangler secret put WEBSOCKET_URL
```

或在 Cloudflare Dashboard 中：
1. 进入 Worker 页面
2. 点击 Settings → Variables & Secrets
3. 点击添加 Secrets 类型的变量

#### ACCOUNT_CONFIGS（必填）
账号配置，JSON 数组格式。示例：

```json
[
  {
    "userId": "用户ID1",
    "token": "用户Token1",
    "platform": "linux"
  },
  {
    "userId": "用户ID2",
    "token": "用户Token2",
    "platform": "android",
    "deviceId": "自定义设备ID（可选）"
  }
]
```

**参数说明：**
- `userId`: 用户 ID（必填，不是用户名、邮箱和手机号）
- `token`: 用户 Token（必填，可以在云湖手机 APP“我”→“进入官网控制台”或“进入云湖官网”通过查看跳转链接的 GET 参数获得）
- `platform`: 平台类型（必填，默认: linux）
  - 可选值: `windows`, `android`, `ios`, `macos`, `Web`, `linux`, `fuchsia`
- `deviceId`: 设备ID（可选，留空则自动生成随机字符串）

#### WEBSOCKET_URL（可选）
WebSocket 服务器地址，默认为: `wss://chat-ws-go.jwzhd.com/ws`

### 3. 定时触发器配置

在 `wrangler.jsonc` 中的 `triggers.crons` 配置 Cron 表达式：

```json
"triggers": {
  "crons": [
    "*/30 * * * *"
  ]
}
```

**常用 Cron 表达式示例：**
- `* * * * *` - 每分钟执行
- `*/30 * * * *` - 每30分钟执行
- `0 * * * *` - 每小时执行
- `0 */4 * * *` - 每4小时执行（默认）
- `0 0 * * *` - 每天午夜执行

Cron 表达式使用 UTC 时间，但是在查看跟踪事件时 Cloudflare 会使用账号设定的时区显示事件发生时间。

## 部署步骤

### 方法一：使用自动化部署脚本（推荐）

项目提供了跨平台的自动化部署脚本，支持 Linux/macOS 和 Windows 系统。脚本会自动：
- 复制 `wrangler.example.jsonc` 为 `wrangler.jsonc`
- 根据您的选择配置存储方式（环境变量或 Secrets）
- 设置 Cron 表达式
- 部署到 Cloudflare

#### Linux/macOS 用户

```bash
# 赋予执行权限
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh
```

脚本会引导：
1. 输入账号配置（JSON 数组格式）
2. 设置 WebSocket URL
3. **选择配置存储方式**（环境变量或 Secrets）
4. 选择 Cron 表达式
5. 确认并部署

#### Windows 用户

```powershell
# 以管理员身份运行 PowerShell
# 允许执行本地脚本
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 运行部署脚本
.\deploy.ps1
```

**注意：** 如果选择使用 Secrets 方式，脚本会在部署前自动调用 `wrangler secret put` 命令设置秘密变量。

### 方法二：手动配置和部署

如果您想手动控制配置过程：

1. **安装依赖**
   ```bash
   npm install
   ```

2. **生成配置文件**
   ```bash
   # 复制模板文件
   cp wrangler.example.jsonc wrangler.jsonc
   ```

3. **配置环境变量**
   
   **选项 A：使用环境变量 (vars)**
   
   编辑 `wrangler.jsonc`，修改 `vars` 部分：
   ```json
   "vars": {
     "ACCOUNT_CONFIGS": "[{\"userId\":\"user1\",\"token\":\"token1\",\"platform\":\"linux\"}]",
     "WEBSOCKET_URL": "wss://chat-ws-go.jwzhd.com/ws"
   }
   ```
   
   **选项 B：使用 Secrets（推荐）**
   
   编辑 `wrangler.jsonc`，删除整个 `vars` 部分（第 39-46 行），然后使用 CLI 设置：
   ```bash
   # 设置账号配置
   npx wrangler secret put ACCOUNT_CONFIGS
   # 粘贴 JSON 格式的账号配置
   
   # 设置 WebSocket URL（可选，如果不使用默认值）
   npx wrangler secret put WEBSOCKET_URL
   ```

4. **配置定时触发器**
   
   编辑 `wrangler.jsonc` 中的 `triggers.crons`：
   ```json
   "triggers": {
     "crons": [
       "0 */4 * * *"
     ]
   }
   ```

5. **本地测试**
   ```bash
   # 启动开发服务器
   npm run dev
   
   # 在另一个终端测试定时触发
   curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*+*+*+*+*"
   ```

6. **部署到 Cloudflare**
   ```bash
   npm run deploy
   ```

### 方法三：通过 Cloudflare Dashboard

1. 访问 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 Workers & Pages
3. 创建新的 Worker 或选择现有 Worker
4. 上传 `src/index.js` 文件内容
5. 在 Settings → Variables 中配置环境变量
6. 在 Settings → Triggers → Cron Triggers 中配置定时触发器

## 查看日志

### 实时日志
```bash
npx wrangler tail
```

### Dashboard 查看
1. 进入 Worker 页面
2. 点击 Observability 标签
3. 查看历史执行记录

日志会显示：
- ✅ 成功登录的账号
- ❌ 失败的账号及错误信息
- 📊 执行结果汇总

## 技术实现

Cloudflare Workers 可以直接作为 WebSocket 客户端连接外部服务器，因此项目直接使用 WebSocket 类完成连接：

1. 建立 WebSocket 连接
2. 发送 WebSocket 握手请求
3. 验证握手响应（HTTP 101）
4. 发送 WebSocket 帧（包含登录数据）
5. 关闭连接

## 故障排查

### 常见问题

1. **连接失败**
   - 检查 WebSocket URL 是否正确
   - 确认账号 token 是否有效
   - 查看日志中的具体错误信息

2. **配置解析失败**
   - 确保 `ACCOUNT_CONFIGS` 是有效的 JSON 格式
   - 检查是否有语法错误（多余的逗号、引号等）

3. **定时任务未执行**
   - 检查 Cron 表达式是否正确
   - 确认 Worker 已成功部署
   - 在 Dashboard 中查看 Observability 事件

### 调试技巧

```bash
# 本地测试特定 Cron 表达式
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*/5+*+*+*+*"

# 查看详细的执行日志
npx wrangler tail --format pretty
```

## 参考项目

云湖用户“无聊的小知识”（ID：8264925）使用 PHP 编写的[自动登录程序](https://github.com/QianLin-Jiaxi/Yhchat-Auto-Login)。本项目作者亦对其做了安全性方面的贡献。

## 许可证

[GNU Affero 通用公共许可证第三版](LICENSE)或任何以后版本。
