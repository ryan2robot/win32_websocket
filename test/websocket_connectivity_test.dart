import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:win32_websocket/win32_websocket.dart';

import 'websocket_server.dart';

/// WebSocket 连通性测试
/// 测试时自动启动本地测试服务器
void main() {
  late WebSocketTestServer? localServer;
  late String serverUrl;

  setUpAll(() async {
    // 启动本地测试服务器
    localServer = await startTestServer();
    serverUrl = 'ws://localhost:${localServer!.port}';
    print('WebSocket 连通性测试服务器已启动: $serverUrl');
  });

  tearDownAll(() async {
    await localServer?.stop();
    print('WebSocket 连通性测试服务器已停止');
  });

  group('WebSocket 连通性测试', () {
    test('基础连通测试 - 可以连接到服务器', () async {
      Win32WebSocket? ws;
      try {
        final stopwatch = Stopwatch()..start();
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));
        stopwatch.stop();

        expect(ws, isNotNull);
        print('连接成功，耗时: ${stopwatch.elapsedMilliseconds}ms');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('延迟测试 - 测量往返延迟', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final latencies = <int>[];
        final completer = Completer<void>();
        var receivedCount = 0;
        final sendTimes = <String, int>{};

        subscription = ws.events.listen((event) {
          if (event is TextDataReceived) {
            final receiveTime = DateTime.now().millisecondsSinceEpoch;
            final sendTime = sendTimes[event.text];
            if (sendTime != null) {
              latencies.add(receiveTime - sendTime);
            }
            receivedCount++;
            if (receivedCount >= 10) {
              completer.complete();
            }
          }
        });

        // 发送 10 条消息测量延迟
        for (var i = 0; i < 10; i++) {
          final message = 'ping_$i';
          sendTimes[message] = DateTime.now().millisecondsSinceEpoch;
          ws.sendText(message);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        await completer.future.timeout(const Duration(seconds: 10));

        expect(latencies.length, equals(10));

        final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
        final minLatency = latencies.reduce((a, b) => a < b ? a : b);
        final maxLatency = latencies.reduce((a, b) => a > b ? a : b);

        print('延迟统计:');
        print('  平均延迟: ${avgLatency.toStringAsFixed(2)}ms');
        print('  最小延迟: ${minLatency}ms');
        print('  最大延迟: ${maxLatency}ms');

        // 验证延迟在合理范围内（应该小于 100ms）
        expect(avgLatency, lessThan(100),
            reason: '平均延迟应该小于 100ms');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('消息回显测试 - 发送和接收文本消息', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final receivedMessages = <String>[];
        final completer = Completer<void>();

        subscription = ws.events.listen((event) {
          if (event is TextDataReceived) {
            receivedMessages.add(event.text);
            if (receivedMessages.length >= 5) {
              completer.complete();
            }
          }
        });

        // 发送测试消息
        final testMessages = [
          'Hello, WebSocket!',
          '测试中文消息',
          'Special chars: !@#\$%^&*()',
          'Unicode: 🚀 🎉 🌟',
          'Numbers: 12345',
        ];

        for (final message in testMessages) {
          ws.sendText(message);
        }

        await completer.future.timeout(const Duration(seconds: 10));

        // 验证所有消息都被正确回显
        for (final message in testMessages) {
          expect(receivedMessages, contains(message),
              reason: '消息 "$message" 应该被回显');
        }

        print('消息回显测试通过，${testMessages.length} 条消息全部正确回显');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('二进制消息测试 - 发送和接收二进制数据', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final receivedData = <Uint8List>[];
        final completer = Completer<void>();

        subscription = ws.events.listen((event) {
          if (event is BinaryDataReceived) {
            receivedData.add(event.data);
            completer.complete();
          }
        });

        // 发送二进制数据
        final testData = Uint8List.fromList(
            List.generate(256, (i) => i)); // 0-255
        ws.sendBytes(testData);

        await completer.future.timeout(const Duration(seconds: 5));

        expect(receivedData.length, equals(1));
        expect(receivedData.first, equals(testData));

        print('二进制消息测试通过，${testData.length} 字节数据正确传输');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('并发连接测试 - 多个客户端同时连接', () async {
      const clientCount = 5;
      final clients = <Win32WebSocket>[];
      final subscriptions = <StreamSubscription>[];

      try {
        // 同时建立多个连接
        final connectFutures = <Future<Win32WebSocket>>[];
        for (var i = 0; i < clientCount; i++) {
          connectFutures.add(Win32WebSocket.connect(Uri.parse(serverUrl)));
        }

        final connectedClients = await Future.wait(connectFutures);
        clients.addAll(connectedClients);

        expect(clients.length, equals(clientCount));
        print('$clientCount 个客户端同时连接成功');

        // 每个客户端发送消息
        final completers = <Completer<void>>[];
        for (var i = 0; i < clientCount; i++) {
          final completer = Completer<void>();
          completers.add(completer);

          final clientIndex = i;
          final sub = clients[i].events.listen((event) {
            if (event is TextDataReceived &&
                event.text == 'Client $clientIndex') {
              completer.complete();
            }
          });
          subscriptions.add(sub);

          clients[i].sendText('Client $clientIndex');
        }

        // 等待所有客户端收到回显
        await Future.wait(completers.map((c) => c.future))
            .timeout(const Duration(seconds: 10));

        print('所有客户端消息回显成功');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        for (final client in clients) {
          try {
            await client.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('长时间连接稳定性测试', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final receivedCount = <int>[0];
        final testDuration = const Duration(seconds: 3);
        final startTime = DateTime.now();

        subscription = ws.events.listen((event) {
          if (event is TextDataReceived) {
            receivedCount[0]++;
          }
        });

        // 在 3 秒内持续发送消息
        var sentCount = 0;
        while (DateTime.now().difference(startTime) < testDuration) {
          ws.sendText('Message $sentCount');
          sentCount++;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // 等待剩余消息回显
        await Future.delayed(const Duration(seconds: 2));

        print('稳定性测试完成:');
        print('  发送消息: $sentCount 条');
        print('  接收消息: ${receivedCount[0]} 条');

        // 验证大部分消息都被接收（允许少量丢失）
        expect(receivedCount[0], greaterThan(sentCount * 0.8),
            reason: '至少 80% 的消息应该被接收');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('子协议协商测试', () async {
      Win32WebSocket? ws;

      try {
        ws = await Win32WebSocket.connect(
          Uri.parse(serverUrl),
          protocols: ['chat', 'superchat'],
        );

        expect(ws, isNotNull);
        print('子协议协商成功');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('连接关闭测试', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;
      CloseReceived? closeEvent;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final completer = Completer<void>();
        subscription = ws.events.listen((event) {
          if (event is CloseReceived) {
            closeEvent = event;
            completer.complete();
          }
        });

        // 发送关闭请求
        await ws.close(1000, 'Test complete');

        await completer.future.timeout(const Duration(seconds: 5));

        expect(closeEvent, isNotNull);
        expect(closeEvent!.code, equals(1005)); // 服务器回显的关闭码

        print('连接关闭测试通过');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
      }
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('WebSocket 压力测试', () {
    test('大量消息压力测试', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        const messageCount = 100;
        var receivedCount = 0;
        final completer = Completer<void>();

        subscription = ws.events.listen((event) {
          if (event is TextDataReceived) {
            receivedCount++;
            if (receivedCount >= messageCount) {
              completer.complete();
            }
          }
        });

        final stopwatch = Stopwatch()..start();

        // 快速发送大量消息
        for (var i = 0; i < messageCount; i++) {
          ws.sendText('Stress test message $i');
        }

        await completer.future.timeout(const Duration(seconds: 30));
        stopwatch.stop();

        print('压力测试完成:');
        print('  发送消息: $messageCount 条');
        print('  接收消息: $receivedCount 条');
        print('  总耗时: ${stopwatch.elapsedMilliseconds}ms');
        print('  平均每条: ${stopwatch.elapsedMilliseconds / messageCount}ms');

        expect(receivedCount, equals(messageCount));
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 35)));

    test('大消息测试', () async {
      Win32WebSocket? ws;
      StreamSubscription? subscription;

      try {
        ws = await Win32WebSocket.connect(Uri.parse(serverUrl));

        final completer = Completer<void>();
        String? receivedMessage;

        subscription = ws.events.listen((event) {
          if (event is TextDataReceived) {
            receivedMessage = event.text;
            completer.complete();
          }
        });

        // 生成大消息（10KB）
        final largeMessage = 'X' * (10 * 1024);
        ws.sendText(largeMessage);

        await completer.future.timeout(const Duration(seconds: 10));

        expect(receivedMessage, equals(largeMessage));
        print('大消息测试通过，成功传输 ${largeMessage.length} 字节');
      } on WebSocketException catch (e) {
        fail('无法连接到测试服务器 $serverUrl: $e');
      } finally {
        await subscription?.cancel();
        if (ws != null) {
          try {
            await ws.close();
          } catch (_) {
            // 忽略关闭时的错误
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
