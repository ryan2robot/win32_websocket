/// Win32 WebSocket - 使用 Windows WinHTTP API 的 Dart WebSocket 库
///
/// 这个库提供了在 Windows 平台上使用操作系统自带的 WinHTTP 进行 WebSocket 连接的功能。
///
/// 兼容 package:web_socket 接口，可以与其他 WebSocket 实现互换使用。
///
/// 主要功能：
/// - 支持 ws:// 和 wss:// (WebSocket Secure) 连接
/// - 发送和接收文本消息
/// - 发送和接收二进制消息
/// - 流式事件处理（兼容 package:web_socket）
/// - 子协议协商支持
///
/// 基本用法（兼容 package:web_socket）：
/// ```dart
/// import 'package:win32_websocket/win32_websocket.dart';
///
/// void main() async {
///   final socket = await Win32WebSocket.connect(
///     Uri.parse('wss://echo.websocket.org'),
///   );
///
///   socket.events.listen((event) async {
///     switch (event) {
///       case TextDataReceived(text: final text):
///         print('收到文本: $text');
///         await socket.close();
///       case BinaryDataReceived(data: final data):
///         print('收到二进制数据: ${data.length} 字节');
///       case CloseReceived(code: final code, reason: final reason):
///         print('连接已关闭: $code [$reason]');
///     }
///   });
///
///   socket.sendText('Hello, WebSocket!');
/// }
/// ```
library;

export 'src/win32_websocket_base.dart';
