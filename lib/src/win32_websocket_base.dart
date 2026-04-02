import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:web_socket/web_socket.dart' as ws;

import 'win32_bindings.dart';

/// 使用 Windows WinHTTP API 的 WebSocket 客户端
///
/// 实现了 [ws.WebSocket] 接口，与 package:web_socket 完全兼容
///
/// 可以直接替换 package:web_socket 中的 WebSocket 实现：
/// ```dart
/// // 原来使用 package:web_socket
/// import 'package:web_socket/web_socket.dart';
/// final socket = await WebSocket.connect(url);
///
/// // 替换为 win32_websocket
/// import 'package:win32_websocket/win32_websocket.dart';
/// final socket = await WebSocket.connect(url); // 完全相同的 API
/// ```
class Win32WebSocket implements ws.WebSocket {
  Pointer<Void>? _session;
  Pointer<Void>? _connection;
  Pointer<Void>? _request;
  Pointer<Void>? _webSocket;

  bool _isClosed = true;
  bool _isClosing = false;
  String? _protocol;

  final _eventController = StreamController<ws.WebSocketEvent>.broadcast();

  // 接收缓冲区大小（默认 64KB）
  final int _bufferSize;

  // 分片消息缓冲区
  final StringBuffer _textFragmentBuffer = StringBuffer();
  final List<int> _binaryFragmentBuffer = <int>[];

  /// 事件流 - 兼容 package:web_socket
  @override
  Stream<ws.WebSocketEvent> get events => _eventController.stream;

  /// 协商后的子协议
  @override
  String get protocol => _protocol ?? '';

  /// 创建新的 WebSocket 连接 - 兼容 package:web_socket
  ///
  /// [bufferSize] 参数指定接收缓冲区大小（字节），默认 64KB。
  /// 如果需要接收更大的消息，可以增加此值。
  static Future<Win32WebSocket> connect(
    Uri url, {
    Iterable<String>? protocols,
    int bufferSize = 65536,
  }) async {
    if (url.scheme != 'ws' && url.scheme != 'wss') {
      throw ArgumentError('URL scheme must be ws or wss: $url');
    }

    if (bufferSize <= 0) {
      throw ArgumentError('Buffer size must be positive: $bufferSize');
    }

    // 检查 WinHTTP WebSocket API 是否可用（需要 Windows 8+）
    if (!WinHttpLibrary.isWebSocketAvailable) {
      throw ws.WebSocketException(
        'WinHTTP WebSocket API is not available. '
        'This feature requires Windows 8 or later.',
      );
    }

    final socket = Win32WebSocket._(bufferSize);
    await socket._connect(url, protocols: protocols);
    return socket;
  }

  Win32WebSocket._(this._bufferSize);

  /// 内部连接方法
  Future<void> _connect(Uri uri, {Iterable<String>? protocols}) async {
    _isClosed = false;

    try {
      final isSecure = uri.scheme == 'wss';
      final port = uri.port != 0 ? uri.port : (isSecure ? 443 : 80);

      // 创建 WinHTTP 会话
      final agentPtr = 'Dart WinHTTP WebSocket'.toNativeUtf16();
      _session = WinHttpLibrary.WinHttpOpen(
        agentPtr,
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        nullptr,
        nullptr,
        0,
      );
      calloc.free(agentPtr);

      if (_session == nullptr || _session!.address == 0) {
        throw ws.WebSocketException(
          'Failed to create WinHTTP session',
        );
      }

      // 设置超时 - 使用较短的超时以便更快发现问题
      // 参数：解析超时、连接超时、发送超时、接收超时（毫秒）
      // -1 表示无限等待
      final timeoutResult = WinHttpLibrary.WinHttpSetTimeouts(
        _session!,
        5000,   // 解析超时 5秒
        5000,   // 连接超时 5秒
        5000,   // 发送超时 5秒
        5000,   // 接收超时 5秒
      );

      if (timeoutResult == 0) {
        final errorCode = WinHttpLibrary.GetLastError();
        print('Warning: Failed to set timeouts (Error: $errorCode)');
      }

      // 创建连接
      final hostPtr = uri.host.toNativeUtf16();
      _connection = WinHttpLibrary.WinHttpConnect(
        _session!,
        hostPtr,
        port,
        0,
      );
      calloc.free(hostPtr);

      if (_connection == nullptr || _connection!.address == 0) {
        throw ws.WebSocketException(
          'Failed to create WinHTTP connection',
        );
      }

      // 创建请求
      final objectName = uri.path.isEmpty ? '/' : uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
      final objectNamePtr = objectName.toNativeUtf16();
      final verbPtr = 'GET'.toNativeUtf16();
      _request = WinHttpLibrary.WinHttpOpenRequest(
        _connection!,
        verbPtr,
        objectNamePtr,
        nullptr,
        nullptr,
        nullptr,
        isSecure ? WINHTTP_FLAG_SECURE : 0,
      );
      calloc.free(objectNamePtr);
      calloc.free(verbPtr);

      if (_request == nullptr || _request!.address == 0) {
        throw ws.WebSocketException(
          'Failed to create WinHTTP request',
        );
      }

      // 设置 WebSocket 升级选项 - 必须在发送请求之前设置
      // 注意：此选项不需要缓冲区参数，只需要设置选项即可
      final optionResult = WinHttpLibrary.WinHttpSetOption(
        _request!,
        WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET,
        nullptr,
        0,
      );

      if (optionResult == 0) {
        final errorCode = WinHttpLibrary.GetLastError();
        // 如果设置失败，记录错误但继续尝试（某些 Windows 版本可能不需要此选项）
        print('Warning: Failed to set WebSocket upgrade option (Error: $errorCode), continuing anyway...');
      }

      // 设置 WebSocket 请求头
      // 注意：WinHTTP WebSocket API 会自动处理 Sec-WebSocket-Key
      final wsHeaders = <String, String>{
        'Upgrade': 'websocket',
        'Connection': 'Upgrade',
        'Sec-WebSocket-Version': '13',
        if (protocols != null && protocols.isNotEmpty)
          'Sec-WebSocket-Protocol': protocols.join(', '),
      };

      for (final entry in wsHeaders.entries) {
        final headerStr = '${entry.key}: ${entry.value}\r\n';
        final headerPtr = headerStr.toNativeUtf16();
        final result = WinHttpLibrary.WinHttpAddRequestHeaders(
          _request!,
          headerPtr,
          -1,
          WINHTTP_ADDREQ_FLAG_ADD,
        );
        calloc.free(headerPtr);
        if (result == 0) {
          throw ws.WebSocketException(
            'Failed to add request header: ${entry.key}',
          );
        }
      }

      // 发送请求
      final sendResult = WinHttpLibrary.WinHttpSendRequest(
        _request!,
        nullptr,
        0,
        nullptr,
        0,
        0,
        0,
      );

      if (sendResult == 0) {
        throw ws.WebSocketException(
          'Failed to send WebSocket request',
        );
      }

      // 接收响应
      final receiveResult = WinHttpLibrary.WinHttpReceiveResponse(_request!, nullptr);
      if (receiveResult == 0) {
        final errorCode = WinHttpLibrary.GetLastError();
        throw ws.WebSocketException(
          'Failed to receive WebSocket response (Error: $errorCode)',
        );
      }

      // 查询 HTTP 状态码
      // 注意：WinHTTP WebSocket 升级后，请求句柄可能无法查询状态码
      // 我们尝试查询，如果失败则假设成功（因为服务器已经接受了升级）
      final statusCodeBuffer = calloc<Uint32>();
      final statusCodeLength = calloc<Uint32>();
      statusCodeLength.value = sizeOf<Uint32>();

      final queryResult = WinHttpLibrary.WinHttpQueryHeaders(
        _request!,
        WINHTTP_QUERY_STATUS_CODE,
        nullptr,
        statusCodeBuffer.cast<Void>(),
        statusCodeLength,
        nullptr,
      );

      int statusCode = 101; // 默认假设成功
      if (queryResult != 0) {
        statusCode = statusCodeBuffer.value;
        print('HTTP Status Code: $statusCode');
      } else {
        final errorCode = WinHttpLibrary.GetLastError();
        print('Warning: Failed to query HTTP status code (Error: $errorCode), assuming 101');
      }
      calloc.free(statusCodeBuffer);
      calloc.free(statusCodeLength);

      if (statusCode != 101) {
        throw ws.WebSocketException(
          'Expected HTTP 101 Switching Protocols, got $statusCode',
        );
      }

      // 升级到 WebSocket
      _webSocket = WinHttpLibrary.WinHttpWebSocketCompleteUpgrade(_request!, 0);
      if (_webSocket == nullptr || _webSocket!.address == 0) {
        final errorCode = WinHttpLibrary.GetLastError();
        throw ws.WebSocketException(
          'Failed to upgrade to WebSocket (Error: $errorCode)',
        );
      }

      // 关闭 HTTP 请求句柄，WebSocket 已经升级成功
      WinHttpLibrary.WinHttpCloseHandle(_request!);
      _request = null;

      // 启动接收循环
      _startReceiveLoop();
    } catch (e) {
      _cleanup();
      _isClosed = true;
      rethrow;
    }
  }

  /// 发送文本消息 - 兼容 package:web_socket
  @override
  void sendText(String text) {
    if (_isClosed || _isClosing) {
      throw ws.WebSocketConnectionClosed();
    }

    final data = utf8.encode(text);
    final buffer = calloc<Uint8>(data.length);
    buffer.asTypedList(data.length).setAll(0, data);

    try {
      final result = WinHttpLibrary.WinHttpWebSocketSend(
        _webSocket!,
        WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE,
        buffer.cast<Void>(),
        data.length,
      );

      if (result != ERROR_SUCCESS) {
        // 静默丢弃，符合 package:web_socket 规范
        return;
      }
    } finally {
      calloc.free(buffer);
    }
  }

  /// 发送二进制消息 - 兼容 package:web_socket
  @override
  void sendBytes(Uint8List data) {
    if (_isClosed || _isClosing) {
      throw ws.WebSocketConnectionClosed();
    }

    final buffer = calloc<Uint8>(data.length);
    buffer.asTypedList(data.length).setAll(0, data);

    try {
      final result = WinHttpLibrary.WinHttpWebSocketSend(
        _webSocket!,
        WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE,
        buffer.cast<Void>(),
        data.length,
      );

      if (result != ERROR_SUCCESS) {
        // 静默丢弃，符合 package:web_socket 规范
        return;
      }
    } finally {
      calloc.free(buffer);
    }
  }

  /// 关闭 WebSocket 连接 - 兼容 package:web_socket
  @override
  Future<void> close([int? code, String? reason]) async {
    if (_isClosed || _isClosing) {
      return;
    }

    _isClosing = true;

    // 验证 code 参数
    if (code != null && code != 1000 && !(code >= 3000 && code <= 4999)) {
      throw ArgumentError('Code must be 1000 or in range 3000-4999: $code');
    }

    // 验证 reason 长度
    final reasonStr = reason ?? '';
    final reasonBytes = utf8.encode(reasonStr);
    if (reasonBytes.length > 123) {
      throw ArgumentError('Reason must not exceed 123 UTF-8 bytes: $reason');
    }

    try {
      if (_webSocket != null && _webSocket!.address != 0) {
        final buffer = calloc<Uint8>(reasonBytes.length);
        buffer.asTypedList(reasonBytes.length).setAll(0, reasonBytes);

        try {
          WinHttpLibrary.WinHttpWebSocketClose(
            _webSocket!,
            code ?? 1005,
            buffer.cast<Void>(),
            reasonBytes.length,
          );
        } finally {
          calloc.free(buffer);
        }
      }
    } finally {
      _cleanup();
      _isClosed = true;
      _isClosing = false;
      // CloseReceived 使用位置参数: CloseReceived([int? code, String reason = ''])
      _eventController.add(ws.CloseReceived(code ?? 1005, reasonStr));
      await _eventController.close();
    }
  }

  /// 启动接收循环
  void _startReceiveLoop() {
    // 在单独的 microtask 中运行接收循环，避免阻塞
    Future(() async {
      while (!_isClosed && !_isClosing && _webSocket != null) {
        await _receiveSingleMessage();
      }
    });
  }

  /// 接收单条消息
  Future<bool> _receiveSingleMessage() async {
    if (_isClosed || _isClosing || _webSocket == null) {
      return false;
    }

    try {
      final buffer = calloc<Uint8>(_bufferSize);
      final bytesRead = calloc<Uint32>();
      final bufferType = calloc<Uint32>();

      try {
        final result = WinHttpLibrary.WinHttpWebSocketReceive(
          _webSocket!,
          buffer.cast<Void>(),
          _bufferSize,
          bytesRead,
          bufferType,
        );

        if (result != ERROR_SUCCESS && result != ERROR_INVALID_OPERATION) {
          // 连接可能已关闭
          if (!_isClosed && !_isClosing) {
            _eventController.add(ws.CloseReceived(1006, 'Connection error'));
          }
          await close(1006, 'Connection error');
          return false;
        }

        final type = bufferType.value;
        final count = bytesRead.value;

        if (type == WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE) {
          if (count > 0) {
            final data = buffer.asTypedList(count);
            final text = utf8.decode(data);
            _eventController.add(ws.TextDataReceived(text));
          }
        } else if (type == WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE) {
          // 处理分片文本消息
          if (count > 0) {
            final data = buffer.asTypedList(count);
            _textFragmentBuffer.write(utf8.decode(data));
          }
        } else if (type == WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE) {
          if (count > 0) {
            final data = Uint8List.fromList(buffer.asTypedList(count));
            _eventController.add(ws.BinaryDataReceived(data));
          }
        } else if (type == WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE) {
          // 处理分片二进制消息
          if (count > 0) {
            _binaryFragmentBuffer.addAll(buffer.asTypedList(count));
          }
        } else if (type == WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE) {
          _eventController.add(ws.CloseReceived(1000, 'Server closed connection'));
          await close();
          return false;
        }

        return !_isClosed && !_isClosing;
      } finally {
        calloc.free(buffer);
        calloc.free(bytesRead);
        calloc.free(bufferType);
      }
    } catch (e) {
      if (!_isClosed && !_isClosing) {
        _eventController.add(ws.CloseReceived(1006, e.toString()));
      }
      return false;
    }
  }

  /// 清理资源
  void _cleanup() {
    if (_webSocket != null && _webSocket!.address != 0) {
      WinHttpLibrary.WinHttpCloseHandle(_webSocket!);
      _webSocket = null;
    }
    if (_request != null && _request!.address != 0) {
      WinHttpLibrary.WinHttpCloseHandle(_request!);
      _request = null;
    }
    if (_connection != null && _connection!.address != 0) {
      WinHttpLibrary.WinHttpCloseHandle(_connection!);
      _connection = null;
    }
    if (_session != null && _session!.address != 0) {
      WinHttpLibrary.WinHttpCloseHandle(_session!);
      _session = null;
    }
  }
}

