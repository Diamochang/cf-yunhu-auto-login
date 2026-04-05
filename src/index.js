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

import { connect } from 'cloudflare:sockets';

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
 * WebSocket 帧编码
 * @param {string} payload - 要发送的文本数据
 * @returns {Uint8Array} WebSocket 帧
 */
function encodeWebSocketFrame(payload) {
	const encoder = new TextEncoder();
	const payloadBytes = encoder.encode(payload);
	const payloadLen = payloadBytes.length;

	// FIN bit + opcode (text frame = 0x01)
	const finAndOpcode = 0x81;

	let frame;
	if (payloadLen <= 125) {
		frame = new Uint8Array(2 + payloadLen);
		frame[0] = finAndOpcode;
		frame[1] = payloadLen;
		frame.set(payloadBytes, 2);
	} else if (payloadLen <= 65535) {
		frame = new Uint8Array(4 + payloadLen);
		frame[0] = finAndOpcode;
		frame[1] = 126;
		frame[2] = (payloadLen >> 8) & 0xff;
		frame[3] = payloadLen & 0xff;
		frame.set(payloadBytes, 4);
	} else {
		frame = new Uint8Array(10 + payloadLen);
		frame[0] = finAndOpcode;
		frame[1] = 127;
		// 大端序写入 8 字节长度
		const view = new DataView(frame.buffer);
		view.setUint32(2, 0, false);
		view.setUint32(6, payloadLen, false);
		frame.set(payloadBytes, 10);
	}

	return frame;
}

/**
 * 创建 WebSocket 握手请求头
 * @param {string} path - WebSocket 路径
 * @param {string} host - 主机名
 * @returns {string} HTTP 请求头
 */
function createWebSocketHandshake(path, host) {
	const key = btoa(
		Array.from(crypto.getRandomValues(new Uint8Array(16)))
			.map(b => String.fromCharCode(b))
			.join('')
	);

	return (
		`GET ${path} HTTP/1.1\r\n` +
		`Host: ${host}\r\n` +
		`Upgrade: websocket\r\n` +
		`Connection: Upgrade\r\n` +
		`Sec-WebSocket-Key: ${key}\r\n` +
		`Sec-WebSocket-Version: 13\r\n` +
		`\r\n`
	);
}

/**
 * 执行单个账号的登录操作
 * @param {Object} config - 账号配置
 * @param {string} targetUrl - WebSocket 服务器地址
 * @returns {Promise<Object>} 登录结果
 */
async function performLogin(config, targetUrl) {
	const result = {
		userId: config.userId,
		success: false,
		error: null
	};

	try {
		// 解析 WebSocket URL
		const url = new URL(targetUrl);
		const hostname = url.hostname;
		const port = url.protocol === 'wss:' ? 443 : 80;
		const path = url.pathname + url.search;

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

		console.log(`🔌 正在连接到: ${hostname}:${port} (协议: ${url.protocol})`);
		console.log(`📍 路径: ${path}`);

		// 连接到 WebSocket 服务器
		let socket;
		try {
			socket = connect(
				{ hostname, port },
				{ secureTransport: url.protocol === 'wss:' ? 'on' : 'off' }
			);
		} catch (connectError) {
			throw new Error(`TCP 连接失败: ${connectError.message}. 请检查域名和端口是否正确。`);
		}

		// 等待连接建立
		try {
			await socket.opened;
			console.log('✅ TCP 连接已建立');
		} catch (openError) {
			socket.close();
			throw new Error(`连接打开失败: ${openError.message}. 可能是域名被阻止或网络不可达。`);
		}

		// 获取 writer
		const writer = socket.writable.getWriter();
		const encoder = new TextEncoder();

		// 发送 WebSocket 握手请求
		const handshake = createWebSocketHandshake(path, hostname);
		await writer.write(encoder.encode(handshake));

		// 读取握手响应
		const reader = socket.readable.getReader();
		const handshakeResponse = await reader.read();
		const responseText = new TextDecoder().decode(handshakeResponse.value);

		// 检查握手是否成功 (HTTP 101 Switching Protocols)
		if (!responseText.startsWith('HTTP/1.1 101')) {
			throw new Error(`握手失败: ${responseText.substring(0, 100)}`);
		}

		// 发送登录数据 (WebSocket 帧)
		const webSocketFrame = encodeWebSocketFrame(jsonPayload);
		await writer.write(webSocketFrame);

		// 短暂延迟确保数据发送完成
		await new Promise(resolve => setTimeout(resolve, 100));

		// 关闭连接
		await writer.close();
		socket.close();

		result.success = true;
		console.log(`✅ 用户 ${config.userId} 登录成功`);
	} catch (error) {
		result.error = error.message;
		console.error(`❌ 用户 ${config.userId} 登录失败:`, error.message);
	}

	return result;
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
