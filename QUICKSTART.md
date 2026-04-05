# 快速开始指南

## 🚀 5分钟快速部署

### 前置要求

- Node.js 16+ 已安装
- Cloudflare 账户（免费即可）

### 步骤 1: 克隆项目

```bash
git clone <repository-url>
cd cf-yunhu-auto-login
npm install
```

### 步骤 2: 登录 Cloudflare

```bash
npx wrangler login
```

这会打开浏览器，授权 Wrangler 访问你的 Cloudflare 账户。

### 步骤 3: 配置账号信息

创建账号配置文件 `my-config.json`:

```json
[
  {
    "userId": "你的用户ID",
    "token": "你的Token",
    "platform": "windows"
  }
]
```

**注意:** 
- `platform` 可选值: `windows`, `android`, `ios`, `Macos`, `Web`, `Linux`, `HamonyOS`
- `deviceId` 可选，不填会自动生成

### 步骤 4: 设置秘密变量

```bash
# 设置账号配置
npx wrangler secret put ACCOUNT_CONFIGS < my-config.json

# 设置 WebSocket URL（可选，使用默认值可跳过）
echo "wss://chat-ws-go.jwzhd.com/ws" | npx wrangler secret put WEBSOCKET_URL
```

### 步骤 5: 部署

```bash
npm run deploy
```

看到 `Published successfully` 即表示部署成功！

### 步骤 6: 验证

```bash
# 查看实时日志
npx wrangler tail
```

等待下一个 Cron 触发时间（默认每30分钟），或手动触发测试。

## 🧪 本地测试

### 启动开发服务器

```bash
npm run dev
```

### 测试定时触发

在另一个终端运行：

```bash
# 立即触发一次执行
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*+*+*+*+*"
```

你应该看到类似这样的输出：

```
⏰ 定时任务触发: * * * * *
📡 WebSocket 服务器: wss://chat-ws-go.jwzhd.com/ws
👥 共 1 个账号需要处理
✅ 用户 xxx 登录成功

========== 执行结果汇总 ==========
总计: 1 个账号
成功: 1 个
失败: 0 个
==================================
```

## ⚙️ 自定义配置

### 修改定时频率

编辑 `wrangler.jsonc`:

```json
{
  "triggers": {
    "crons": [
      "*/30 * * * *"  // 修改这里的 Cron 表达式
    ]
  }
}
```

常用 Cron 表达式：
- `* * * * *` - 每分钟
- `*/30 * * * *` - 每30分钟（默认）
- `0 * * * *` - 每小时
- `0 */6 * * *` - 每6小时
- `0 0 * * *` - 每天午夜

修改后重新部署：

```bash
npm run deploy
```

### 添加更多账号

```bash
# 更新账号配置
npx wrangler secret put ACCOUNT_CONFIGS
# 粘贴新的 JSON 数组（包含所有账号）

# 重新部署
npm run deploy
```

### 更换 WebSocket 服务器

```bash
npx wrangler secret put WEBSOCKET_URL
# 输入新的 WebSocket URL

npm run deploy
```

## 📊 监控和维护

### 查看日志

```bash
# 实时日志
npx wrangler tail

# 带格式的日志
npx wrangler tail --format pretty
```

### 查看执行历史

1. 访问 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 Workers & Pages
3. 选择你的 Worker
4. 点击 Logs 标签

### 更新配置

```bash
# 列出所有秘密变量
npx wrangler secret list

# 删除秘密变量
npx wrangler secret delete ACCOUNT_CONFIGS

# 重新设置
npx wrangler secret put ACCOUNT_CONFIGS < my-config.json
```

## ❓ 常见问题

### Q: 如何知道任务是否在正常运行？

A: 运行 `npx wrangler tail` 查看日志，应该定期看到执行记录。

### Q: 可以手动触发执行吗？

A: 可以！在 Cloudflare Dashboard 中保存并部署 Worker（即使没有修改），会立即触发一次执行。

### Q: 支持多少个账号？

A: 理论上无限制，但建议每次执行不超过 100 个账号，避免超时。

### Q: 如何停止自动执行？

A: 在 `wrangler.jsonc` 中将 `crons` 设置为空数组 `[]`，然后重新部署。

### Q: 免费额度够用吗？

A: 完全够用！免费版每天 100,000 次请求，每30分钟执行一次每天只需 48 次。

## 🔗 相关链接

- [完整文档](README.md)
- [部署检查清单](DEPLOYMENT_CHECKLIST.md)
- [迁移总结](MIGRATION_SUMMARY.md)
- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [Cron Triggers 文档](https://developers.cloudflare.com/workers/configuration/cron-triggers/)

## 💡 提示

1. **首次部署建议**: 先本地测试，确认无误后再部署到生产环境
2. **安全性**: 永远不要将包含真实 token 的文件提交到 Git
3. **监控**: 定期检查日志，确保任务正常运行
4. **备份**: 保存好你的账号配置，以便快速恢复

## 🆘 需要帮助？

如果遇到问题：

1. 查看 [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) 中的故障排查部分
2. 检查日志中的错误信息
3. 确认配置格式正确
4. 验证网络连接正常

---

**祝你使用愉快！** 🎉
