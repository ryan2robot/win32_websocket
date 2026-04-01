import 'dart:typed_data';
import 'package:win32_websocket/win32_websocket.dart';

void main() async {
  // 测试 API 兼容性
  print('Testing Win32WebSocket API...');

  // 测试事件类
  const textEvent = TextDataReceived('Hello');
  print('TextDataReceived: ${textEvent.text}');

  final binaryEvent = BinaryDataReceived(Uint8List.fromList([1, 2, 3]));
  print('BinaryDataReceived: ${binaryEvent.data.length} bytes');

  const closeEvent = CloseReceived(code: 1000, reason: 'Test');
  print('CloseReceived: ${closeEvent.code}, ${closeEvent.reason}');

  // 测试异常
  const exception = WebSocketException('Test error');
  print('WebSocketException: $exception');

  const closedException = WebSocketConnectionClosed();
  print('WebSocketConnectionClosed: $closedException');

  print('All API tests passed!');
}
