import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 简单的 WebSocket 回显服务器，用于测试
class WebSocketTestServer {
  HttpServer? _server;
  final _clients = <WebSocket>[];
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// 启动服务器
  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind('localhost', port);
    print('WebSocket server started on ws://localhost:${_server!.port}');

    _server!.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        print('Client connected, total: ${_clients.length}');

        socket.listen(
          (message) {
            // 回显消息
            print('Received: $message');
            socket.add(message);
          },
          onDone: () {
            _clients.remove(socket);
            print('Client disconnected, total: ${_clients.length}');
          },
          onError: (error) {
            print('Client error: $error');
            _clients.remove(socket);
          },
        );
      } else {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('WebSocket connections only')
          ..close();
      }
    });
  }

  /// 停止服务器
  Future<void> stop() async {
    for (final client in _clients.toList()) {
      await client.close();
    }
    _clients.clear();

    await _server?.close();
    _server = null;
    print('WebSocket server stopped');
  }
}

/// 启动服务器并返回地址
Future<WebSocketTestServer> startTestServer() async {
  final server = WebSocketTestServer();
  await server.start();
  return server;
}
