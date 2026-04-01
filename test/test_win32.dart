import 'package:win32_websocket/win32_websocket.dart';

void main() async {
  try {
    print('Connecting to ws://localhost:61227...');
    final ws = await Win32WebSocket.connect(Uri.parse('ws://localhost:61227'));
    print('Connected!');
    await ws.close();
    print('Closed');
  } catch (e) {
    print('Error: $e');
  }
}
