import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 使用 shelf_web_socket 的 WebSocket 回显服务器，用于测试
class WebSocketTestServer {
  HttpServer? _server;
  final _clients = <WebSocketChannel>[];
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  static final _random = Random();

  /// 生成随机端口 (49152-65535, 动态/私有端口范围)
  static int generateRandomPort() {
    return 49152 + _random.nextInt(65535 - 49152 + 1);
  }

  /// 启动服务器
  /// [port] 为 0 时使用随机端口
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

    // 如果 port 为 0，使用随机端口
    final targetPort = port == 0 ? generateRandomPort() : port;
    _server = await shelf_io.serve(handler, 'localhost', targetPort);
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
