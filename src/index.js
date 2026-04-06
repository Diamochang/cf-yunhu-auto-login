/**
 * Welcome to Cloudflare Workers!
 *
 * This is a template for a Scheduled Worker: a Worker that can run on a
 * configurable interval:
 * https://developers.cloudflare.com/workers/platform/triggers/cron-triggers/
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Run `curl "http://localhost:8787/__scheduled?cron=*+*+*+*+*"` to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

/**
 * 生成随机字符串
 * @param {number} length - 字符串长度
 * @param {string} charset - 字符集
 * @returns {string} 随机字符串
 */
function randomString(length, charset = '0123456789abcdefghijklmnopqrstuvwxyz') {
	let result = '';
	const charsetLen = charset.length;
	for (let i = 0; i < length; i++) {
		result += charset.charAt(Math.floor(Math.random() * charsetLen));
	}
	return result;
}

/**
 * 生成 UUID v4 (无连字符)
 * @returns {string} UUID 字符串
 */
function uuid4NoDash() {
	const bytes = crypto.getRandomValues(new Uint8Array(16));
	bytes[6] = (bytes[6] & 0x0f) | 0x40;
	bytes[8] = (bytes[8] & 0x3f) | 0x80;
	return Array.from(bytes)
		.map(b => b.toString(16).padStart(2, '0'))
		.join('');
}

/**
 * 执行单个账号的登录操作
 * @param {Object} config - 账号配置
 * @param {string} targetUrl - WebSocket 服务器地址
 * @returns {Promise<Object>} 登录结果
 */
async function performLogin(config, targetUrl) {
	return new Promise((resolve) => {
		const result = {
			userId: config.userId,
			success: false,
			error: null
		};

		// 如果没有提供 deviceId，则自动生成
		const deviceId = config.deviceId || randomString(50);

		// 构建登录数据
		const loginData = {
			seq: uuid4NoDash(),
			cmd: 'login',
			data: {
				userId: config.userId,
				token: config.token,
				platform: config.platform || 'linux',
				deviceId: deviceId
			}
		};

		const jsonPayload = JSON.stringify(loginData);
		let ws = null;
		let timeoutId = null;

		const cleanup = () => {
			if (timeoutId) clearTimeout(timeoutId);
			if (ws && ws.readyState === WebSocket.OPEN) {
				ws.close();
			}
		};

		// 设置超时
		timeoutId = setTimeout(() => {
			console.error(`❌ 用户 ${config.userId} 登录超时`);
			result.error = '连接超时';
			cleanup();
			resolve(result);
		}, 10000);

		try {
			ws = new WebSocket(targetUrl);

			ws.onopen = () => {
				console.log(`✅ WebSocket 连接已建立 (${config.userId})`);
				// 发送登录数据
				ws.send(jsonPayload);
				// 短暂延迟确保消息发送完成，然后关闭连接
				setTimeout(() => {
					if (ws && ws.readyState === WebSocket.OPEN) {
						ws.close();
					}
					result.success = true;
					console.log(`✅ 用户 ${config.userId} 登录成功`);
					cleanup();
					resolve(result);
				}, 500);
			};

			ws.onerror = (err) => {
				console.error(`❌ 用户 ${config.userId} WebSocket 错误:`, err);
				result.error = 'WebSocket 错误';
				cleanup();
				resolve(result);
			};

			ws.onclose = (event) => {
				// 正常关闭时不重复 resolve，避免重复调用
				if (result.success === false && result.error === null) {
					console.log(`用户 ${config.userId} WebSocket 意外关闭: code=${event.code}, reason=${event.reason}`);
					result.error = `连接关闭 (${event.code})`;
					cleanup();
					resolve(result);
				}
			};
		} catch (error) {
			console.error(`❌ 用户 ${config.userId} 创建 WebSocket 失败:`, error.message);
			result.error = error.message;
			cleanup();
			resolve(result);
		}
	});
}

export default {
	async fetch(req) {
		const url = new URL(req.url);
		url.pathname = "/__scheduled";
		url.searchParams.append("cron", "* * * * *");
		return new Response(`To test the scheduled handler, ensure you have used the "--test-scheduled" then try running "curl ${url.href}".`);
	},

	// 定时触发器处理函数
	async scheduled(event, env, ctx) {
		console.log(`⏰ 定时任务触发: ${event.cron}`);

		// 从环境变量获取配置
		// 格式: JSON 数组，例如:
		// [{"userId":"user1","token":"token1","platform":"windows"},{"userId":"user2","token":"token2","platform":"android"}]
		const configsJson = env.ACCOUNT_CONFIGS || '[]';
		let configs;
		try {
			configs = JSON.parse(configsJson);
		} catch (error) {
			console.error('❌ 解析账号配置失败:', error.message);
			return;
		}

		if (!configs || configs.length === 0) {
			console.warn('⚠️ 没有配置任何账号');
			return;
		}

		const targetUrl = env.WEBSOCKET_URL || 'wss://chat-ws-go.jwzhd.com/ws';
		console.log(`📡 WebSocket 服务器: ${targetUrl}`);
		console.log(`👥 共 ${configs.length} 个账号需要处理`);

		const results = [];

		// 依次处理每个账号
		for (const config of configs) {
			if (!config.userId || !config.token) {
				console.warn('⚠️ 跳过无效配置:', config);
				continue;
			}

			const result = await performLogin(config, targetUrl);
			results.push(result);

			// 在每个请求之间添加小延迟，避免并发压力
			await new Promise(resolve => setTimeout(resolve, 500));
		}

		// 统计结果
		const successCount = results.filter(r => r.success).length;
		const failCount = results.length - successCount;

		console.log('\n========== 执行结果汇总 ==========');
		console.log(`总计: ${results.length} 个账号`);
		console.log(`成功: ${successCount} 个`);
		console.log(`失败: ${failCount} 个`);
		console.log('==================================\n');

		// 如果有失败的，输出详细信息
		if (failCount > 0) {
			console.error('失败的账号详情:');
			results.filter(r => !r.success).forEach(r => {
				console.error(`  - 用户 ${r.userId}: ${r.error}`);
			});
		}
	},
};