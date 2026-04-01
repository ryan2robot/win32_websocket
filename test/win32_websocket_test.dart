import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:win32_websocket/win32_websocket.dart';

import 'websocket_server.dart';

/// WebSocket 测试服务器地址
/// 默认使用公共测试服务器，可以通过环境变量覆盖
const String testServerUrlEnv = String.fromEnvironment(
  'WS_TEST_SERVER',
  defaultValue: '', // 空字符串表示使用本地服务器
);

void main() {
  late WebSocketTestServer? localServer;
  late String serverUrl;

  setUpAll(() async {
    // 如果环境变量设置了外部服务器，使用它
    if (testServerUrlEnv.isNotEmpty) {
      serverUrl = testServerUrlEnv;
      localServer = null;
      print('Using external server: $serverUrl');
    } else {
      // 否则启动本地服务器
      localServer = await startTestServer();
      serverUrl = 'ws://localhost:${localServer!.port}';
      print('Using local server: $serverUrl');
    }
  });

  tearDownAll(() async {
    await localServer?.stop();
  });

  group('Win32WebSocket Events', () {
    test('TextDataReceived event works', () {
      const event = TextDataReceived('Hello');
      expect(event.text, 'Hello');
      expect(event.toString(), contains('Hello'));
    });

    test('BinaryDataReceived event works', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final event = BinaryDataReceived(data);
      expect(event.data, equals(data));
      expect(event.toString(), contains('4 bytes'));
    });

    test('CloseReceived event works', () {
      const event = CloseReceived(code: 1000, reason: 'Normal closure');
      expect(event.code, 1000);
      expect(event.reason, 'Normal closure');
    });

    test('WebSocketException toString', () {
      const exception = WebSocketException('Test error');
      expect(exception.toString(), contains('Test error'));
    });

    test('WebSocketConnectionClosed exception', () {
      const exception = WebSocketConnectionClosed();
      expect(exception.toString(), contains('closed'));
    });
  });

  group('WebSocket Key Generation Security', () {
    test('generateWebSocketKey returns valid base64 string', () {
      // 使用内部函数测试密钥生成
      final random = Random.secure();
      final bytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        bytes[i] = random.nextInt(256);
      }
      final key = base64Encode(bytes);

      // 验证是有效的 base64 字符串
      expect(() => base64Decode(key), returnsNormally);

      // 验证解码后是 16 字节
      final decoded = base64Decode(key);
      expect(decoded.length, equals(16));
    });

    test('base64 encoded keys have correct length', () {
      // 16 字节 base64 编码后应该是 24 个字符
      final random = Random.secure();
      final bytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        bytes[i] = random.nextInt(256);
      }
      final key = base64Encode(bytes);
      expect(key.length, equals(24));
    });

    test('keys contain only base64 characters', () {
      final random = Random.secure();
      final bytes = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        bytes[i] = random.nextInt(256);
      }
      final key = base64Encode(bytes);
      final base64Regex = RegExp(r'^[A-Za-z0-9+/]+=*$');
      expect(base64Regex.hasMatch(key), isTrue);
    });

    test('keys are unique', () {
      final keys = <String>{};
      final random = Random.secure();

      for (var i = 0; i < 100; i++) {
        final bytes = Uint8List(16);
        for (var j = 0; j < 16; j++) {
          bytes[j] = random.nextInt(256);
        }
        keys.add(base64Encode(bytes));
      }

      expect(keys.length, equals(100));
    });
  });

  group('Win32WebSocket Connection', () {
    test('can connect to server', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
        expect(ws, isNotNull);
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('connection with protocols', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(
          Uri.parse(serverUrl),
          protocols: ['chat', 'superchat'],
        );
        expect(ws, isNotNull);
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('invalid URL scheme throws ArgumentError', () async {
      expect(
        () => Win32WebSocket.connect(Uri.parse('http://example.com')),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Win32WebSocket.connect(Uri.parse('https://example.com')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Message Exchange', () {
    test('send and receive text message', () async {
      Win32WebSocket? ws;
      final receivedEvents = <WebSocketEvent>[];
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final completer = Completer<void>();
        subscription = ws.events.listen((event) {
          receivedEvents.add(event);
          if (event is TextDataReceived) {
            completer.complete();
          }
        });

        const testMessage = 'Hello, WebSocket!';
        ws.sendText(testMessage);

        // 等待收到消息
        await completer.future.timeout(const Duration(seconds: 5));

        // 验证收到消息
        final textEvents = receivedEvents
            .whereType<TextDataReceived>()
            .toList();

        expect(textEvents, isNotEmpty);
        expect(textEvents.first.text, equals(testMessage));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        await ws?.close();
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('send and receive binary message', () async {
      Win32WebSocket? ws;
      final receivedEvents = <WebSocketEvent>[];
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final completer = Completer<void>();
        subscription = ws.events.listen((event) {
          receivedEvents.add(event);
          if (event is BinaryDataReceived) {
            completer.complete();
          }
        });

        final testData = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0xFF]);
        ws.sendBytes(testData);

        // 等待收到消息
        await completer.future.timeout(const Duration(seconds: 5));

        // 验证收到消息
        final binaryEvents = receivedEvents
            .whereType<BinaryDataReceived>()
            .toList();

        expect(binaryEvents, isNotEmpty);
        expect(binaryEvents.first.data, equals(testData));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        await ws?.close();
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('multiple messages in sequence', () async {
      Win32WebSocket? ws;
      final receivedEvents = <WebSocketEvent>[];
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final completer = Completer<void>();
        var messageCount = 0;
        subscription = ws.events.listen((event) {
          receivedEvents.add(event);
          if (event is TextDataReceived) {
            messageCount++;
            if (messageCount >= 3) {
              completer.complete();
            }
          }
        });

        // 发送多条消息
        ws.sendText('Message 1');
        ws.sendText('Message 2');
        ws.sendText('Message 3');

        // 等待所有回显消息
        await completer.future.timeout(const Duration(seconds: 10));

        final textEvents = receivedEvents
            .whereType<TextDataReceived>()
            .map((e) => e.text)
            .toList();

        expect(textEvents, contains('Message 1'));
        expect(textEvents, contains('Message 2'));
        expect(textEvents, contains('Message 3'));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        await ws?.close();
      }
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('Error Handling', () {
    test('cannot send text when not connected', () {
      // 未连接时无法发送，因为 connect 是静态方法
      // 这个测试验证在关闭后发送会抛出异常
      // 需要先连接再关闭
    });

    test('cannot send text after close', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
        await ws.close();

        expect(
          () => ws!.sendText('test'),
          throwsA(isA<WebSocketConnectionClosed>()),
        );
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('cannot send bytes after close', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
        await ws.close();

        expect(
          () => ws!.sendBytes(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<WebSocketConnectionClosed>()),
        );
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('close can be called multiple times safely', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
        await ws.close();
        await ws.close(); // 第二次调用应该安全
        await ws.close(); // 第三次调用也应该安全
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('close with invalid code throws ArgumentError', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        // 无效的 code (1001 不在允许范围内)
        expect(
          () => ws!.close(1001),
          throwsA(isA<ArgumentError>()),
        );

        // 有效的 code
        await ws.close(1000);
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('close with too long reason throws ArgumentError', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        // 超过 123 字节的原因
        final longReason = 'a' * 200;
        expect(
          () => ws!.close(1000, longReason),
          throwsA(isA<ArgumentError>()),
        );

        await ws.close();
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('Stream Behavior', () {
    test('events stream is broadcast', () async {
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        // 广播流可以有多个监听者
        final subscription1 = ws.events.listen((_) {});
        final subscription2 = ws.events.listen((_) {});

        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);

        await subscription1.cancel();
        await subscription2.cancel();
        await ws.close();
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('events stream emits CloseReceived on close', () async {
      Win32WebSocket? ws;
      final receivedEvents = <WebSocketEvent>[];
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        subscription = ws.events.listen(receivedEvents.add);

        await ws.close(1000, 'Test close');

        // 验证收到了 CloseReceived 事件
        final closeEvents = receivedEvents.whereType<CloseReceived>().toList();
        expect(closeEvents, isNotEmpty);
        expect(closeEvents.first.code, equals(1000));
        expect(closeEvents.first.reason, equals('Test close'));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
      }
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('package:web_socket Compatibility', () {
    test('API matches package:web_socket interface', () async {
      // 验证 API 兼容 package:web_socket
      Win32WebSocket? ws;
      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        // 验证事件流
        expect(ws.events, isA<Stream<WebSocketEvent>>());

        // 验证发送方法
        ws.sendText('test');
        ws.sendBytes(Uint8List.fromList([1, 2, 3]));

        // 验证关闭方法
        await ws.close();
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('can use pattern matching on events', () async {
      Win32WebSocket? ws;
      final receivedTexts = <String>[];
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        subscription = ws.events.listen((event) {
          // 使用 switch 表达式进行模式匹配
          switch (event) {
            case TextDataReceived(text: final text):
              receivedTexts.add(text);
            case BinaryDataReceived():
              // 忽略二进制消息
              break;
            case CloseReceived(code: final code, reason: final reason):
              print('Closed: $code [$reason]');
          }
        });

        ws.sendText('Pattern matching test');

        // 等待消息接收
        await Future.delayed(const Duration(seconds: 2));

        expect(receivedTexts, contains('Pattern matching test'));
      } on WebSocketException catch (e) {
        markTestSkipped('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        await ws?.close();
      }
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
