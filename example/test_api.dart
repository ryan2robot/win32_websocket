import 'dart:typed_data';
import 'package:win32_websocket/win32_websocket.dart';

/// 本示例展示如何使用与 package:web_socket 兼容的 API
///
/// 这个代码可以直接替换 package:web_socket 的代码，无需修改
void main() async {
  // WebSocket 服务器地址
  // 可以使用公共测试服务器，如：wss://echo.websocket.org/
  // 或者本地服务器，如：ws://localhost:8080
  final url = Uri.parse('wss://echo.websocket.org/');

  print('正在连接到 $url...');

  try {
    // 创建 WebSocket 连接 - 使用与 package:web_socket 完全相同的 API
    final socket = await WebSocket.connect(url);
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

/// 示例：使用 Win32WebSocket 类（底层实现）
///
/// 如果你需要使用 Windows 特定的功能，可以直接使用 Win32WebSocket 类
void exampleUsingWin32WebSocket() async {
  final url = Uri.parse('wss://echo.websocket.org/');

  // 直接使用 Win32WebSocket 类
  final socket = await Win32WebSocket.connect(url);

  socket.events.listen((event) async {
    switch (event) {
      case TextDataReceived(text: final text):
        print('收到: $text');
        await socket.close();
      case BinaryDataReceived(data: final data):
        print('收到二进制: ${data.length} 字节');
      case CloseReceived(code: final code, reason: final reason):
        print('关闭: $code - $reason');
    }
  });

  socket.sendText('Hello from Win32WebSocket!');
}

/// 示例：发送二进制数据
void exampleBinaryData() async {
  final url = Uri.parse('wss://echo.websocket.org/');
  final socket = await WebSocket.connect(url);

  socket.events.listen((event) async {
    switch (event) {
      case BinaryDataReceived(data: final data):
        print('收到二进制响应: ${data.length} 字节');
        await socket.close();
      case CloseReceived(code: final code, reason: final reason):
        print('连接关闭: $code');
      default:
        break;
    }
  });

  // 发送二进制数据
  final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
  socket.sendBytes(bytes);
}

/// 示例：使用子协议
void exampleWithProtocols() async {
  final url = Uri.parse('wss://example.com/socket');

  // 指定子协议
  final socket = await WebSocket.connect(
    url,
    protocols: ['chat', 'superchat'],
  );

  socket.events.listen((event) {
    // 处理事件...
  });
}
