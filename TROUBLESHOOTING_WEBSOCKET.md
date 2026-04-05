# WebSocket 连接问题诊断

## 当前问题

错误信息：
```
proxy request failed, cannot connect to the specified address. 
It looks like you might be trying to connect to a HTTP-based service — consider using fetch instead
```

## 可能的原因

1. **Cloudflare Workers 限制**
   - TCP Sockets API 不能连接到某些域名
   - 目标服务器可能阻止了 Cloudflare 的 IP
   - 域名解析失败

2. **网络问题**
   - 服务器不可达
   - 防火墙阻止
   - DNS 解析问题

3. **配置问题**
   - URL 格式错误
   - 端口不正确

## 🔍 诊断步骤

### 步骤 1: 使用测试脚本

临时替换 `wrangler.jsonc` 中的 main 文件：

```json
{
  "main": "test-connection.js",
  ...
}
```

然后部署并访问：

```bash
npm run deploy
```

在浏览器中访问你的 Worker URL，或在终端运行：

```bash
curl https://your-worker.your-subdomain.workers.dev/
```

这将返回详细的连接测试结果。

### 步骤 2: 检查日志

```bash
npx wrangler tail
```

查看详细的错误信息和调试输出。

### 步骤 3: 验证 WebSocket 服务器

在本地测试 WebSocket 服务器是否可访问：

```bash
# 使用 wscat 工具
npm install -g wscat
wscat -c wss://chat-ws-go.jwzhd.com/ws

# 或使用 websocat
websocat wss://chat-ws-go.jwzhd.com/ws
```

如果本地也无法连接，说明服务器本身有问题。

## 💡 解决方案

### 方案 A: 确认服务器地址正确

检查 `WEBSOCKET_URL` 是否正确：

```bash
# 更新 WebSocket URL
npx wrangler secret put WEBSOCKET_URL
# 输入正确的地址
```

### 方案 B: 尝试不同的连接方式

如果 TCP Sockets 无法工作，可能需要：

1. **使用其他服务器** - 找一个可以被 Cloudflare Workers 访问的 WebSocket 服务器
2. **使用 HTTP API** - 如果服务器提供 HTTP 登录接口，改用 `fetch()`
3. **使用中转服务** - 在自己的服务器上搭建 WebSocket 中转

### 方案 C: 检查 Cloudflare 限制

Cloudflare Workers 不能连接到：
- Cloudflare 自己的 IP 范围
- 私有网络地址（localhost, 192.168.x.x 等）
- 某些被阻止的域名

### 方案 D: 使用 Durable Objects

如果需要可靠的 WebSocket 连接，考虑使用 Durable Objects：

```javascript
// 在 Durable Object 中可以建立更稳定的 WebSocket 连接
export class WebSocketHandler {
  async fetch(request) {
    // 这里可以使用标准的 WebSocket API
  }
}
```

但这需要付费计划。

## 📋 检查清单

- [ ] WebSocket URL 格式正确（wss:// 或 ws://）
- [ ] 域名可以正常解析
- [ ] 服务器在线且接受连接
- [ ] 端口开放（443 for wss, 80 for ws）
- [ ] 没有被 Cloudflare 阻止
- [ ] 本地可以成功连接

## 🔧 临时解决方案

如果确实无法通过 Cloudflare Workers 连接，可以考虑：

1. **使用 VPS 运行原 PHP 脚本**
   - 成本稍高但更可靠
   - 完全控制

2. **使用其他 Serverless 平台**
   - AWS Lambda
   - Google Cloud Functions
   - 这些平台可能有不同的网络限制

3. **混合方案**
   - 使用 Cloudflare Workers 作为触发器
   - 调用你自己的服务器执行 WebSocket 连接

## 📞 获取帮助

如果以上方法都不行：

1. 查看 Cloudflare 社区论坛
2. 提交 Cloudflare 支持工单
3. 检查服务器的访问日志，看是否有来自 Cloudflare 的请求

---

**最后更新:** 2026-04-06
