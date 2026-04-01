import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 使用 shelf_web_socket 的 WebSocket 回显服务器，用于测试
class WebSocketTestServer {
  HttpServer? _server;
  final _clients = <WebSocketChannel>[];
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  /// 启动服务器
  Future<void> start({int port = 0}) async {
    final handler = webSocketHandler((WebSocketChannel webSocket) {
      _clients.add(webSocket);
      print('Client connected, total: ${_clients.length}');

      webSocket.stream.listen(
        (message) {
          // 回显消息
          print('Received: $message');
          webSocket.sink.add(message);
        },
        onDone: () {
          _clients.remove(webSocket);
          print('Client disconnected, total: ${_clients.length}');
        },
        onError: (error) {
          print('Client error: $error');
          _clients.remove(webSocket);
        },
      );
    });

    _server = await shelf_io.serve(handler, 'localhost', port);
    print('WebSocket server started on ws://localhost:${_server!.port}');
  }

  /// 停止服务器
  Future<void> stop() async {
    for (final client in _clients.toList()) {
      await client.sink.close();
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
