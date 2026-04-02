import 'dart:typed_data';
import 'package:win32_websocket/win32_websocket.dart';

void main() async {
  // WebSocket 服务器地址
  // 可以使用公共测试服务器，如：wss://echo.websocket.org/
  // 或者本地服务器，如：ws://localhost:8080
  final url = Uri.parse('wss://echo.websocket.org/');

  print('正在连接到 $url...');

  try {
    // 创建 WebSocket 连接
    final socket = await Win32WebSocket.connect(url);
    print('连接成功！');

    // 监听服务器发送的事件
    socket.events.listen((event) async {
      switch (event) {
        case TextDataReceived(text: final text):
          print('收到文本消息: $text');
          // 收到响应后关闭连接
          await socket.close();
          print('连接已关闭');

        case BinaryDataReceived(data: final data):
          print('收到二进制数据: ${data.length} 字节');

        case CloseReceived(code: final code, reason: final reason):
          print('服务器关闭连接: code=$code, reason=$reason');
      }
    });

    // 发送文本消息到服务器
    final message = 'Hello, WebSocket!';
    print('发送消息: $message');
    socket.sendText(message);

    // 等待一小段时间让服务器响应
    await Future.delayed(Duration(seconds: 3));

  } catch (e) {
    print('连接错误: $e');
  }

  print('程序结束');
}
