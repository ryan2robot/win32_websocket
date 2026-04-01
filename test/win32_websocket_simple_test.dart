import 'dart:async';
import 'package:test/test.dart';
import 'package:win32_websocket/win32_websocket.dart';
import 'websocket_server.dart';

/// Win32WebSocket 简单测试
void main() {
  late WebSocketTestServer? localServer;
  late String serverUrl;

  setUpAll(() async {
    localServer = await startTestServer();
    serverUrl = 'ws://localhost:${localServer!.port}';
    print('测试服务器已启动: $serverUrl');
  });

  tearDownAll(() async {
    await localServer?.stop();
    print('测试服务器已停止');
  });

  test('Win32WebSocket 基础连接测试', () async {
    Win32WebSocket? ws;
    try {
      print('正在连接 $serverUrl...');
      ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
      print('连接成功!');
      expect(ws, isNotNull);
    } catch (e) {
      fail('连接失败: $e');
    } finally {
      if (ws != null) {
        try {
          await ws.close();
        } catch (_) {}
      }
    }
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('Win32WebSocket 消息收发测试', () async {
    Win32WebSocket? ws;
    StreamSubscription? subscription;

    try {
      print('正在连接...');
      ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
      print('连接成功，准备接收消息');

      final receivedMessages = <String>[];
      final completer = Completer<void>();

      subscription = ws.events.listen((event) {
        print('收到事件: $event');
        if (event is TextDataReceived) {
          receivedMessages.add(event.text);
          if (receivedMessages.length >= 2) {
            completer.complete();
          }
        }
      });

      // 发送测试消息
      print('发送消息: Hello');
      ws.sendText('Hello');
      print('发送消息: World');
      ws.sendText('World');

      // 等待接收消息
      await completer.future.timeout(const Duration(seconds: 5));

      expect(receivedMessages, contains('Hello'));
      expect(receivedMessages, contains('World'));
      print('消息收发测试通过!');
    } catch (e) {
      fail('测试失败: $e');
    } finally {
      await subscription?.cancel();
      if (ws != null) {
        try {
          await ws.close();
        } catch (_) {}
      }
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
