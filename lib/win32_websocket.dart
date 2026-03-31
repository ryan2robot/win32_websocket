/// Win32 WebSocket - 使用 Windows WinHTTP API 的 Dart WebSocket 库
///
/// 这个库提供了在 Windows 平台上使用操作系统自带的 WinHTTP 进行 WebSocket 连接的功能。
///
/// 主要功能：
/// - 支持 ws:// 和 wss:// (WebSocket Secure) 连接
/// - 发送和接收文本消息
/// - 发送和接收二进制消息
/// - 流式消息处理
/// - 连接状态管理
///
/// 基本用法：
/// ```dart
/// import 'package:win32_websocket/win32_websocket.dart';
///
/// void main() async {
///   final ws = WinHttpWebSocket();
///
///   // 监听消息
///   ws.messages.listen((message) {
///     if (message.type == WebSocketMessageType.text) {
///       print('收到文本: ${message.text}');
///     }
///   });
///
///   // 连接服务器
///   await ws.connect('wss://echo.websocket.org');
///
///   // 发送消息
///   await ws.sendText('Hello, WebSocket!');
///
///   // 关闭连接
///   await ws.close();
/// }
/// ```
library;

export 'src/win32_websocket_base.dart';
