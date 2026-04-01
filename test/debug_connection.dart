import 'dart:io';
import 'dart:async';

void main() async {
  // 创建一个简单的 HTTP 服务器来查看收到的请求
  final server = await HttpServer.bind('localhost', 0);
  print('Debug server listening on port ${server.port}');

  server.listen((request) async {
    print('\n=== New Request ===');
    print('Method: ${request.method}');
    print('URI: ${request.uri}');
    print('Headers:');
    request.headers.forEach((name, values) {
      print('  $name: ${values.join(", ")}');
    });

    // 检查是否是 WebSocket 升级请求
    final connection = request.headers.value('connection') ?? '';
    final upgrade = request.headers.value('upgrade') ?? '';

    if (connection.toLowerCase().contains('upgrade') &&
        upgrade.toLowerCase() == 'websocket') {
      print('This is a WebSocket upgrade request!');

      // 尝试升级
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        print('WebSocket upgrade successful!');

        socket.listen(
          (message) {
            print('Received: $message');
            socket.add('Echo: $message');
          },
          onDone: () => print('Client disconnected'),
          onError: (e) => print('Error: $e'),
        );
      } catch (e) {
        print('Upgrade failed: $e');
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Upgrade failed: $e')
          ..close();
      }
    } else {
      print('Not a WebSocket request');
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket only')
        ..close();
    }
  });

  print('Press Enter to stop...');
  await stdin.first;
  await server.close();
}
