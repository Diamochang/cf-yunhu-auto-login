# 部署检查清单

在部署云呼自动登录 Worker 之前，请确保完成以下步骤：

## ✅ 准备阶段

- [ ] 已安装 Node.js 和 npm
- [ ] 已安装 Wrangler CLI (`npm install -g wrangler`)
- [ ] 已登录 Cloudflare 账户 (`wrangler login`)
- [ ] 已有有效的云呼账号 userId 和 token

## ✅ 配置阶段

### 1. 账号配置

- [ ] 准备好所有需要自动登录的账号信息
- [ ] 创建 JSON 格式的账号配置数组
- [ ] 确认每个账号的 platform 类型正确

示例配置：
```json
[
  {
    "userId": "你的用户ID",
    "token": "你的Token",
    "platform": "windows"
  }
]
```

### 2. 环境变量设置

使用以下命令设置敏感信息（推荐）：

```bash
# 设置账号配置
npx wrangler secret put ACCOUNT_CONFIGS
# 粘贴 JSON 数组

# 设置 WebSocket URL（可选，使用默认值可不设置）
npx wrangler secret put WEBSOCKET_URL
# 输入: wss://chat-ws-go.jwzhd.com/ws
```

或者在 `wrangler.jsonc` 中修改 `vars` 部分（不推荐用于生产环境）。

### 3. 定时触发器配置

- [ ] 确认 Cron 表达式符合需求
- [ ] 默认为 `*/30 * * * *`（每30分钟执行一次）
- [ ] 如需修改，编辑 `wrangler.jsonc` 中的 `triggers.crons`

常用 Cron 表达式：
- `* * * * *` - 每分钟
- `*/30 * * * *` - 每30分钟（默认）
- `0 * * * *` - 每小时
- `0 */6 * * *` - 每6小时
- `0 0 * * *` - 每天午夜

## ✅ 测试阶段

### 本地测试

```bash
# 1. 启动开发服务器
npm run dev

# 2. 在另一个终端测试定时触发
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*+*+*+*+*"

# 3. 查看输出日志，确认：
#    - 配置解析成功
#    - WebSocket 连接成功
#    - 登录请求发送成功
```

### 验证要点

- [ ] 无语法错误
- [ ] 配置正确解析
- [ ] 能够连接到 WebSocket 服务器
- [ ] 登录请求发送成功
- [ ] 日志输出清晰完整

## ✅ 部署阶段

```bash
# 部署到 Cloudflare
npm run deploy
```

部署后验证：

- [ ] 部署成功，无错误信息
- [ ] 在 Cloudflare Dashboard 中看到 Worker
- [ ] 在 Settings → Triggers 中看到 Cron Trigger
- [ ] 在 Settings → Variables 中看到环境变量

## ✅ 部署后验证

### 1. 查看实时日志

```bash
npx wrangler tail
```

等待下一个 Cron 触发时间，或手动触发测试。

### 2. 手动触发测试

访问 Cloudflare Dashboard：
1. 进入 Worker 页面
2. 点击 Quick Edit
3. 点击 Save and Deploy（即使没有修改）
4. 这会立即触发一次执行

或在 Dashboard 中：
1. Settings → Triggers → Cron Triggers
2. 点击 Cron 旁边的测试按钮（如果有）

### 3. 检查执行结果

在日志中应该看到：

```
⏰ 定时任务触发: */30 * * * *
📡 WebSocket 服务器: wss://chat-ws-go.jwzhd.com/ws
👥 共 X 个账号需要处理
✅ 用户 XXX 登录成功
========== 执行结果汇总 ==========
总计: X 个账号
成功: X 个
失败: 0 个
==================================
```

## ❌ 故障排查

### 问题：配置解析失败

**症状：** 日志显示 "解析账号配置失败"

**解决：**
1. 检查 JSON 格式是否正确
2. 确保没有多余的逗号或引号
3. 使用 JSON 验证工具检查格式

### 问题：连接失败

**症状：** 日志显示 "握手失败" 或 "连接失败"

**解决：**
1. 检查 WebSocket URL 是否正确
2. 确认网络连接正常
3. 检查账号 token 是否有效
4. 查看具体错误信息

### 问题：定时任务未执行

**症状：** 到达预定时间但没有日志输出

**解决：**
1. 检查 Cron 表达式是否正确
2. 确认 Worker 已成功部署
3. 在 Dashboard 中查看 Cron Events
4. 注意：Cron 变更可能需要几分钟生效

### 问题：部分账号失败

**症状：** 有些账号成功，有些失败

**解决：**
1. 检查失败账号的配置
2. 确认 userId 和 token 正确
3. 查看具体错误信息
4. 尝试单独测试失败的账号

## 📊 监控和维护

### 日常监控

- 定期查看日志，确认任务正常执行
- 关注失败率，如有异常及时处理
- 检查账号 token 是否过期

### 更新配置

添加或删除账号：

```bash
# 更新账号配置
npx wrangler secret put ACCOUNT_CONFIGS
# 粘贴新的 JSON 数组

# 重新部署
npm run deploy
```

### 修改定时频率

1. 编辑 `wrangler.jsonc`
2. 修改 `triggers.crons` 中的 Cron 表达式
3. 重新部署：`npm run deploy`

## 🔒 安全建议

- ✅ 使用 `wrangler secret put` 存储敏感信息
- ✅ 不要将包含真实 token 的配置文件提交到 Git
- ✅ 定期更换账号 token
- ✅ 限制 Worker 的访问权限
- ❌ 不要在代码中硬编码 token
- ❌ 不要分享包含敏感信息的截图

## 📝 相关命令速查

```bash
# 登录 Cloudflare
wrangler login

# 本地开发
npm run dev

# 测试定时触发
curl "http://localhost:8787/cdn-cgi/handler/scheduled?cron=*+*+*+*+*"

# 查看实时日志
npx wrangler tail

# 部署
npm run deploy

# 设置秘密变量
npx wrangler secret put ACCOUNT_CONFIGS
npx wrangler secret put WEBSOCKET_URL

# 列出所有秘密变量
npx wrangler secret list

# 删除秘密变量
npx wrangler secret delete ACCOUNT_CONFIGS
```

## ✨ 完成！

如果以上所有步骤都已完成且验证通过，恭喜你！云呼自动登录 Worker 已经成功部署并运行。

---

**最后更新：** 2026-04-06
