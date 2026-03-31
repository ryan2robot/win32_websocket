import 'dart:async';
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

    group('Connection', () {
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
  });
}
