import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:win32_websocket/win32_websocket.dart';

/// WebSocket 测试服务器地址
/// 默认使用公共测试服务器，可以通过环境变量覆盖
const String _testServerUrl = String.fromEnvironment(
  'WS_TEST_SERVER',
  defaultValue: 'wss://echo.websocket.org',
);

void main() {
  group('WinHttpWebSocket', () {
    test('can be instantiated', () {
      final ws = WinHttpWebSocket();
      expect(ws, isNotNull);
      expect(ws.state, equals(WebSocketState.closed));
      expect(ws.isConnected, isFalse);
      ws.dispose();
    });

    test('initial state is closed', () {
      final ws = WinHttpWebSocket();
      expect(ws.state, WebSocketState.closed);
      expect(ws.isConnected, false);
      ws.dispose();
    });

    test('WebSocketMessage text factory works', () {
      final message = WebSocketMessage.text('Hello');
      expect(message.type, WebSocketMessageType.text);
      expect(message.text, 'Hello');
      expect(message.binary, isNull);
    });

    test('WebSocketMessage binary factory works', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final message = WebSocketMessage.binary(data);
      expect(message.type, WebSocketMessageType.binary);
      expect(message.binary, equals(data));
      expect(message.text, isNull);
    });

    test('WebSocketMessage close factory works', () {
      final message = WebSocketMessage.close(1000, 'Normal closure');
      expect(message.type, WebSocketMessageType.close);
      expect(message.data, containsPair('code', 1000));
      expect(message.data, containsPair('reason', 'Normal closure'));
    });

    test('WebSocketException toString includes error code', () {
      final exception = WebSocketException('Test error', errorCode: 123);
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('123'));
    });

    test('WebSocketException toString without error code', () {
      final exception = WebSocketException('Test error');
      expect(exception.toString(), equals('WebSocketException: Test error'));
    });
  });

  group('WebSocket Key Generation Security', () {
    test('generateWebSocketKey returns valid base64 string', () {
      final key = generateWebSocketKey();

      // 验证是有效的 base64 字符串
      expect(() => base64Decode(key), returnsNormally);

      // 验证解码后是 16 字节
      final decoded = base64Decode(key);
      expect(decoded.length, equals(16));
    });

    test('generateWebSocketKey generates unique keys', () {
      // 生成多个密钥
      final keys = <String>{};
      for (var i = 0; i < 100; i++) {
        keys.add(generateWebSocketKey());
      }

      // 所有密钥应该唯一
      expect(keys.length, equals(100));
    });

    test('generateWebSocketKey uses cryptographically secure random', () {
      // 连续快速生成密钥，验证它们不同
      // 这证明不是使用时间戳作为唯一熵源
      final key1 = generateWebSocketKey();
      final key2 = generateWebSocketKey();
      final key3 = generateWebSocketKey();

      expect(key1, isNot(equals(key2)));
      expect(key2, isNot(equals(key3)));
      expect(key1, isNot(equals(key3)));
    });

    test('generateWebSocketKey produces correct length', () {
      // 16 字节 base64 编码后应该是 24 个字符
      // (16 * 4 / 3 = 21.33，向上取整到 24，无填充)
      // 实际上标准 base64 编码 16 字节会产生 24 个字符
      final key = generateWebSocketKey();
      expect(key.length, equals(24));
    });

    test('generateWebSocketKey contains only base64 characters', () {
      final key = generateWebSocketKey();
      final base64Regex = RegExp(r'^[A-Za-z0-9+/]+=*$');
      expect(base64Regex.hasMatch(key), isTrue);
    });

    test('keys are not predictable (statistical test)', () {
      // 生成大量密钥并检查字节分布
      final byteCounts = List.filled(256, 0);

      // 生成 1000 个密钥
      for (var i = 0; i < 1000; i++) {
        final key = generateWebSocketKey();
        final bytes = base64Decode(key);
        for (final byte in bytes) {
          byteCounts[byte]++;
        }
      }

      // 检查每个字节值都出现了一定次数
      // 在 16000 个字节中，每个值平均出现约 62.5 次
      // 允许较大的偏差范围
      final minExpected = 20; // 最小期望出现次数
      final maxExpected = 150; // 最大期望出现次数

      var withinRange = 0;
      for (final count in byteCounts) {
        if (count >= minExpected && count <= maxExpected) {
          withinRange++;
        }
      }

      // 至少 90% 的字节值应该在合理范围内
      expect(withinRange / 256, greaterThan(0.9));
    });
  });

  group('WinHttpWebSocket Connection', () {
    test('state changes during connection lifecycle', () async {
      final ws = WinHttpWebSocket();
      final states = <WebSocketState>[];

      // 监听状态变化
      final subscription = ws.stateChanges.listen(states.add);

      // 初始状态
      expect(ws.state, WebSocketState.closed);

      // 注意：这里使用一个公共的 WebSocket 测试服务器
      // 如果连接失败，测试会被跳过而不是失败
      try {
        await ws.connect(_testServerUrl);

        // 验证状态变化序列
        expect(states, contains(WebSocketState.connecting));
        expect(states, contains(WebSocketState.open));
        expect(ws.state, WebSocketState.open);
        expect(ws.isConnected, isTrue);

        await ws.close();

        expect(states, contains(WebSocketState.closing));
        expect(states, contains(WebSocketState.closed));
        expect(ws.state, WebSocketState.closed);
        expect(ws.isConnected, isFalse);
      } on WebSocketException catch (e) {
        // 如果连接失败（例如网络问题），跳过测试
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        await subscription.cancel();
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('cannot connect when already connected', () async {
      final ws = WinHttpWebSocket();

      try {
        await ws.connect(_testServerUrl);

        // 尝试再次连接应该抛出异常
        expect(
          () => ws.connect(_testServerUrl),
          throwsA(isA<WebSocketException>()),
        );
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Message Exchange', () {
    test('send and receive text message', () async {
      final ws = WinHttpWebSocket();
      final receivedMessages = <WebSocketMessage>[];

      // 监听消息
      final subscription = ws.messages.listen(receivedMessages.add);

      try {
        await ws.connect(_testServerUrl);

        const testMessage = 'Hello, WebSocket!';
        await ws.sendText(testMessage);

        // 等待回显消息
        await Future.delayed(const Duration(seconds: 2));

        // 验证收到消息
        final textMessages = receivedMessages
            .where((m) => m.type == WebSocketMessageType.text)
            .toList();

        expect(textMessages, isNotEmpty);
        expect(textMessages.first.text, equals(testMessage));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        await subscription.cancel();
        await ws.close();
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('send and receive binary message', () async {
      final ws = WinHttpWebSocket();
      final receivedMessages = <WebSocketMessage>[];

      final subscription = ws.messages.listen(receivedMessages.add);

      try {
        await ws.connect(_testServerUrl);

        final testData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0xFF]);
        await ws.sendBinary(testData);

        // 等待回显消息
        await Future.delayed(const Duration(seconds: 2));

        // 验证收到消息
        final binaryMessages = receivedMessages
            .where((m) => m.type == WebSocketMessageType.binary)
            .toList();

        expect(binaryMessages, isNotEmpty);
        expect(binaryMessages.first.binary, equals(testData));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        await subscription.cancel();
        await ws.close();
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('multiple messages in sequence', () async {
      final ws = WinHttpWebSocket();
      final receivedMessages = <WebSocketMessage>[];

      final subscription = ws.messages.listen(receivedMessages.add);

      try {
        await ws.connect(_testServerUrl);

        // 发送多条消息
        await ws.sendText('Message 1');
        await ws.sendText('Message 2');
        await ws.sendText('Message 3');

        // 等待所有回显消息
        await Future.delayed(const Duration(seconds: 3));

        final textMessages = receivedMessages
            .where((m) => m.type == WebSocketMessageType.text)
            .map((m) => m.text)
            .toList();

        expect(textMessages, contains('Message 1'));
        expect(textMessages, contains('Message 2'));
        expect(textMessages, contains('Message 3'));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        await subscription.cancel();
        await ws.close();
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Error Handling', () {
    test('cannot send text when not connected', () {
      final ws = WinHttpWebSocket();

      expect(
        () => ws.sendText('test'),
        throwsA(
          isA<WebSocketException>().having(
            (e) => e.message,
            'message',
            contains('not open'),
          ),
        ),
      );

      ws.dispose();
    });

    test('cannot send binary when not connected', () {
      final ws = WinHttpWebSocket();

      expect(
        () => ws.sendBinary(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<WebSocketException>().having(
            (e) => e.message,
            'message',
            contains('not open'),
          ),
        ),
      );

      ws.dispose();
    });

    test('close can be called multiple times safely', () async {
      final ws = WinHttpWebSocket();

      try {
        await ws.connect(_testServerUrl);
        await ws.close();
        await ws.close(); // 第二次调用应该安全
        await ws.close(); // 第三次调用也应该安全

        expect(ws.state, WebSocketState.closed);
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Stream Behavior', () {
    test('messages stream is broadcast', () async {
      final ws = WinHttpWebSocket();

      // 广播流可以有多个监听者
      final subscription1 = ws.messages.listen((_) {});
      final subscription2 = ws.messages.listen((_) {});

      expect(subscription1, isNotNull);
      expect(subscription2, isNotNull);

      await subscription1.cancel();
      await subscription2.cancel();
      ws.dispose();
    });

    test('stateChanges stream emits events', () async {
      final ws = WinHttpWebSocket();
      final events = <WebSocketState>[];

      final subscription = ws.stateChanges.listen(events.add);

      try {
        await ws.connect(_testServerUrl);
        await ws.close();

        // 验证收到了状态变化事件
        expect(events, isNotEmpty);
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $_testServerUrl: $e');
      } finally {
        await subscription.cancel();
        ws.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
