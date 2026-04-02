import 'package:win32_websocket/win32_websocket.dart';

void main() async {
  try {
    // 使用 shelf_web_socket 服务器的端口
    print('Connecting to ws://localhost:53854...');
    final ws = await Win32WebSocket.connect(Uri.parse('ws://localhost:53854'));
    print('Connected!');
    await ws.close();
    print('Closed');
  } catch (e) {
    print('Error: $e');
  }
}
