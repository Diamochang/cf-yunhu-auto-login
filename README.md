# 云呼自动登录 - Cloudflare Workers 定时任务

这是一个基于 Cloudflare Workers 的定时自动登录服务，用于定期向云呼 WebSocket 服务器发送登录请求以保持账号在线状态。

## 功能特性

- ✅ 支持多账号配置
- ✅ 定时自动执行（默认每30分钟）
- ✅ 自动生成设备ID
- ✅ 支持多种平台类型（Windows、Android、iOS、MacOS、Web、Linux、HarmonyOS）
- ✅ 详细的日志输出
- ✅ 错误处理和重试机制

## 配置说明

### 1. 环境变量配置

在 `wrangler.jsonc` 文件中配置以下变量，或通过 Cloudflare Dashboard / Wrangler CLI 设置：

#### ACCOUNT_CONFIGS（必填）
账号配置，JSON 数组格式。示例：

```json
[
  {
    "userId": "用户ID1",
    "token": "用户Token1",
    "platform": "windows"
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
- `userId`: 用户ID（必填）
- `token`: 用户Token（必填）
- `platform`: 平台类型（可选，默认: windows）
  - 可选值: `windows`, `android`, `ios`, `Macos`, `Web`, `Linux`, `HamonyOS`
- `deviceId`: 设备ID（可选，留空则自动生成50位随机字符串）

#### WEBSOCKET_URL（可选）
WebSocket 服务器地址，默认为: `wss://chat-ws-go.jwzhd.com/ws`

### 2. 定时触发器配置

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
- `*/30 * * * *` - 每30分钟执行（默认）
- `0 * * * *` - 每小时执行
- `0 */6 * * *` - 每6小时执行
- `0 0 * * *` - 每天午夜执行

Cron 表达式使用 UTC 时间。

## 部署步骤

### 方法一：使用 Wrangler CLI（推荐）

1. **安装依赖**
   ```bash
   npm install
   ```

2. **配置环境变量**
   
   方式 A：在 `wrangler.jsonc` 中直接修改 `vars` 部分
   
   方式 B：使用 Wrangler 命令设置（更安全，推荐用于生产环境）
   ```bash
   # 设置账号配置
   npx wrangler secret put ACCOUNT_CONFIGS
   # 粘贴 JSON 格式的账号配置
   
   # 设置 WebSocket URL（可选）
   npx wrangler secret put WEBSOCKET_URL
   # 输入 WebSocket 服务器地址
   ```

3. **本地测试**
   ```bash
   # 启动开发服务器
   npm run dev
   
   # 在另一个终端测试定时触发
   curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*+*+*+*+*"
   ```

4. **部署到 Cloudflare**
   ```bash
   npm run deploy
   ```

### 方法二：通过 Cloudflare Dashboard

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
2. 点击 Logs 标签
3. 查看历史执行记录

日志会显示：
- ✅ 成功登录的账号
- ❌ 失败的账号及错误信息
- 📊 执行结果汇总

## 技术实现

### WebSocket 连接
由于 Cloudflare Workers 不能直接作为 WebSocket 客户端连接外部服务器，本项目使用 TCP Sockets API (`cloudflare:sockets`) 手动实现 WebSocket 协议：

1. 建立 TCP/TLS 连接
2. 发送 WebSocket 握手请求
3. 验证握手响应（HTTP 101）
4. 发送 WebSocket 帧（包含登录数据）
5. 关闭连接

### 安全考虑
- Token 等敏感信息应使用 `wrangler secret put` 存储，而非明文写在配置文件中
- 定时触发器无需访问密钥验证，因为只有 Cloudflare 内部可以触发
- 所有连接使用 TLS 加密（wss://）

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
   - 在 Dashboard 中查看 Cron Events

### 调试技巧

```bash
# 本地测试特定 Cron 表达式
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*/5+*+*+*+*"

# 查看详细的执行日志
npx wrangler tail --format pretty
```

## 限制和注意事项

- Cloudflare Workers 免费套餐：每天最多 100,000 次请求
- 每个 Worker 执行时间限制：10ms（免费）/ 30s（付费）
- 同时打开的 TCP 连接数有限制
- Cron 触发器变更可能需要几分钟才能生效

## 许可证

MIT

## 更新日志

- 2026-04-06: 初始版本，从 PHP 代码迁移到 Cloudflare Workers
