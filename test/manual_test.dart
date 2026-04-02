import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:win32_websocket/win32_websocket.dart';

void main() async {
  // 启动 shelf_web_socket 服务器
  final handler = webSocketHandler((WebSocketChannel webSocket) {
    print('Client connected');
    webSocket.stream.listen(
      (message) {
        print('Server received: $message');
        webSocket.sink.add(message);
      },
      onDone: () => print('Client disconnected'),
    );
  });

  final server = await shelf_io.serve(handler, 'localhost', 0);
  final url = 'ws://localhost:${server.port}';
  print('Server started on $url');

  // 使用 Win32WebSocket 连接
  try {
    print('\nConnecting with Win32WebSocket...');
    final ws = await Win32WebSocket.connect(Uri.parse(url));
    print('Connected!');

    // 发送测试消息
    ws.sendText('Hello from Win32WebSocket!');
    print('Message sent');

    // 接收响应
    await for (final event in ws.events.take(1)) {
      print('Received event: $event');
      if (event is TextDataReceived) {
        print('Received message: ${event.text}');
      }
    }

    await ws.close();
    print('Connection closed');
  } catch (e) {
    print('Error: $e');
  }

  await server.close();
  print('Server stopped');
}
