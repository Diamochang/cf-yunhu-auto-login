/**
 * 测试 WebSocket 连接
 * 用于诊断连接问题
 */

import { connect } from 'cloudflare:sockets';

export default {
	async fetch(request, env, ctx) {
		const url = new URL(request.url);
		
		// 从查询参数获取测试地址，默认使用配置的地址
		const testUrl = url.searchParams.get('url') || env.WEBSOCKET_URL || 'wss://chat-ws-go.jwzhd.com/ws';
		
		try {
			const wsUrl = new URL(testUrl);
			const hostname = wsUrl.hostname;
			const port = wsUrl.protocol === 'wss:' ? 443 : 80;
			
			console.log(`测试连接: ${hostname}:${port}`);
			
			// 尝试建立 TCP 连接
			const socket = connect(
				{ hostname, port },
				{ secureTransport: wsUrl.protocol === 'wss:' ? 'on' : 'off' }
			);
			
			await socket.opened;
			console.log('✅ TCP 连接成功');
			
			socket.close();
			
			return new Response(JSON.stringify({
				success: true,
				message: 'TCP 连接成功',
				hostname: hostname,
				port: port,
				protocol: wsUrl.protocol
			}, null, 2), {
				headers: { 'Content-Type': 'application/json' }
			});
			
		} catch (error) {
			console.error('❌ 连接失败:', error.message);
			
			return new Response(JSON.stringify({
				success: false,
				error: error.message,
				testUrl: testUrl,
				suggestions: [
					'检查域名是否正确',
					'确认端口是否开放',
					'尝试使用其他 WebSocket 服务器',
					'Cloudflare Workers 可能无法连接到此域名'
				]
			}, null, 2), {
				status: 500,
				headers: { 'Content-Type': 'application/json' }
			});
		}
	}
};
