import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  // 创建中间件来记录请求
  final logRequests = shelf.createMiddleware(
    requestHandler: (request) {
      print('=== Incoming Request ===');
      print('Method: ${request.method}');
      print('URL: ${request.url}');
      print('Headers:');
      request.headers.forEach((k, v) => print('  $k: $v'));
      return null; // 继续处理
    },
  );

  final wsHandler = webSocketHandler((WebSocketChannel webSocket) {
    print('WebSocket client connected');
    webSocket.stream.listen(
      (message) {
        print('Server received: $message');
        webSocket.sink.add(message);
      },
      onDone: () => print('Client disconnected'),
    );
  });

  final handler = logRequests.addHandler(wsHandler);

  final server = await shelf_io.serve(handler, 'localhost', 0);
  final url = 'ws://localhost:${server.port}';
  print('Server started on $url');
  print('Press Enter to stop...');

  await stdin.first;
  await server.close();
  print('Server stopped');
}
