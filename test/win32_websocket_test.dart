import 'package:test/test.dart';
import 'package:win32_websocket/win32_websocket.dart';

void main() {
  group('WinHttpWebSocket', () {
    test('can be instantiated', () {
      final ws = WinHttpWebSocket();
      expect(ws, isNotNull);
      expect(ws.state, equals(WebSocketState.closed));
      expect(ws.isConnected, isFalse);
      ws.dispose();
    });

    test('initial state is closed', () {
      final ws = WinHttpWebSocket();
      expect(ws.state, WebSocketState.closed);
      expect(ws.isConnected, false);
      ws.dispose();
    });

    test('WebSocketMessage text factory works', () {
      final message = WebSocketMessage.text('Hello');
      expect(message.type, WebSocketMessageType.text);
      expect(message.text, 'Hello');
      expect(message.binary, isNull);
    });

    test('WebSocketMessage binary factory works', () {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final message = WebSocketMessage.binary(data);
      expect(message.type, WebSocketMessageType.binary);
      expect(message.binary, equals(data));
      expect(message.text, isNull);
    });

    test('WebSocketMessage close factory works', () {
      final message = WebSocketMessage.close(1000, 'Normal closure');
      expect(message.type, WebSocketMessageType.close);
      expect(message.data, containsPair('code', 1000));
      expect(message.data, containsPair('reason', 'Normal closure'));
    });

    test('WebSocketException toString includes error code', () {
      final exception = WebSocketException('Test error', errorCode: 123);
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('123'));
    });

    test('WebSocketException toString without error code', () {
      final exception = WebSocketException('Test error');
      expect(exception.toString(), equals('WebSocketException: Test error'));
    });
  });
}
