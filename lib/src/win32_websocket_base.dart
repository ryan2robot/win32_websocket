import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// WinHTTP 常量
const int WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = 0;
const int WINHTTP_ACCESS_TYPE_NO_PROXY = 1;
const int WINHTTP_ACCESS_TYPE_NAMED_PROXY = 3;

const int WINHTTP_FLAG_SECURE = 0x00800000;

// WinHTTP 选项
const int WINHTTP_OPTION_SECURITY_FLAGS = 31;
const int WINHTTP_OPTION_UPGRADE_TO_WEB_SOCKET = 114;

// 安全标志
const int SECURITY_FLAG_IGNORE_UNKNOWN_CA = 0x00000100;
const int SECURITY_FLAG_IGNORE_CERT_WRONG_USAGE = 0x00000200;
const int SECURITY_FLAG_IGNORE_CERT_CN_INVALID = 0x00001000;
const int SECURITY_FLAG_IGNORE_CERT_DATE_INVALID = 0x00002000;

const int WINHTTP_ADDREQ_FLAG_ADD = 0x20000000;
const int WINHTTP_ADDREQ_FLAG_REPLACE = 0x80000000;

// WinHTTP 查询信息标志
const int WINHTTP_QUERY_STATUS_CODE = 19;

const int WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE = 0;
const int WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE = 1;
const int WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE = 2;
const int WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE = 3;
const int WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE = 4;

const int ERROR_SUCCESS = 0;
const int ERROR_INVALID_OPERATION = 4317;
const int ERROR_IO_PENDING = 997;

// WinHTTP 函数类型定义
typedef WinHttpOpenC = Pointer<Void> Function(Pointer<Utf16> pszAgentW, Uint32 dwAccessType, Pointer<Utf16> pszProxyW, Pointer<Utf16> pszProxyBypassW, Uint32 dwFlags);
typedef WinHttpOpenDart = Pointer<Void> Function(Pointer<Utf16> pszAgentW, int dwAccessType, Pointer<Utf16> pszProxyW, Pointer<Utf16> pszProxyBypassW, int dwFlags);

typedef WinHttpConnectC = Pointer<Void> Function(Pointer<Void> hSession, Pointer<Utf16> pswzServerName, Uint32 nServerPort, Uint32 dwReserved);
typedef WinHttpConnectDart = Pointer<Void> Function(Pointer<Void> hSession, Pointer<Utf16> pswzServerName, int nServerPort, int dwReserved);

typedef WinHttpOpenRequestC = Pointer<Void> Function(Pointer<Void> hConnect, Pointer<Utf16> pwszVerb, Pointer<Utf16> pwszObjectName, Pointer<Utf16> pwszVersion, Pointer<Utf16> pwszReferrer, Pointer<Utf16> ppwszAcceptTypes, Uint32 dwFlags);
typedef WinHttpOpenRequestDart = Pointer<Void> Function(Pointer<Void> hConnect, Pointer<Utf16> pwszVerb, Pointer<Utf16> pwszObjectName, Pointer<Utf16> pwszVersion, Pointer<Utf16> pwszReferrer, Pointer<Utf16> ppwszAcceptTypes, int dwFlags);

typedef WinHttpAddRequestHeadersC = Int32 Function(Pointer<Void> hRequest, Pointer<Utf16> lpszHeaders, Uint32 dwHeadersLength, Uint32 dwModifiers);
typedef WinHttpAddRequestHeadersDart = int Function(Pointer<Void> hRequest, Pointer<Utf16> lpszHeaders, int dwHeadersLength, int dwModifiers);

typedef WinHttpSetOptionC = Int32 Function(Pointer<Void> hInternet, Uint32 dwOption, Pointer<Void> lpBuffer, Uint32 dwBufferLength);
typedef WinHttpSetOptionDart = int Function(Pointer<Void> hInternet, int dwOption, Pointer<Void> lpBuffer, int dwBufferLength);

typedef WinHttpQueryHeadersC = Int32 Function(Pointer<Void> hRequest, Uint32 dwInfoLevel, Pointer<Utf16> pwszName, Pointer<Void> lpBuffer, Pointer<Uint32> lpdwBufferLength, Pointer<Uint32> lpdwIndex);
typedef WinHttpQueryHeadersDart = int Function(Pointer<Void> hRequest, int dwInfoLevel, Pointer<Utf16> pwszName, Pointer<Void> lpBuffer, Pointer<Uint32> lpdwBufferLength, Pointer<Uint32> lpdwIndex);

typedef WinHttpSendRequestC = Int32 Function(Pointer<Void> hRequest, Pointer<Utf16> lpszHeaders, Uint32 dwHeadersLength, Pointer<Void> lpOptional, Uint32 dwOptionalLength, Uint32 dwTotalLength, UintPtr dwContext);
typedef WinHttpSendRequestDart = int Function(Pointer<Void> hRequest, Pointer<Utf16> lpszHeaders, int dwHeadersLength, Pointer<Void> lpOptional, int dwOptionalLength, int dwTotalLength, int dwContext);

typedef WinHttpReceiveResponseC = Int32 Function(Pointer<Void> hRequest, Pointer<Void> lpReserved);
typedef WinHttpReceiveResponseDart = int Function(Pointer<Void> hRequest, Pointer<Void> lpReserved);

typedef WinHttpWebSocketCompleteUpgradeC = Pointer<Void> Function(Pointer<Void> hRequest, UintPtr dwContext);
typedef WinHttpWebSocketCompleteUpgradeDart = Pointer<Void> Function(Pointer<Void> hRequest, int dwContext);

typedef WinHttpWebSocketSendC = Int32 Function(Pointer<Void> hWebSocket, Uint32 eBufferType, Pointer<Void> pvBuffer, Uint32 dwBufferLength);
typedef WinHttpWebSocketSendDart = int Function(Pointer<Void> hWebSocket, int eBufferType, Pointer<Void> pvBuffer, int dwBufferLength);

typedef WinHttpWebSocketReceiveC = Int32 Function(Pointer<Void> hWebSocket, Pointer<Void> pvBuffer, Uint32 dwBufferLength, Pointer<Uint32> pdwBytesRead, Pointer<Uint32> peBufferType);
typedef WinHttpWebSocketReceiveDart = int Function(Pointer<Void> hWebSocket, Pointer<Void> pvBuffer, int dwBufferLength, Pointer<Uint32> pdwBytesRead, Pointer<Uint32> peBufferType);

typedef WinHttpWebSocketCloseC = Int32 Function(Pointer<Void> hWebSocket, Uint16 usStatus, Pointer<Void> pvReason, Uint32 dwReasonLength);
typedef WinHttpWebSocketCloseDart = int Function(Pointer<Void> hWebSocket, int usStatus, Pointer<Void> pvReason, int dwReasonLength);

typedef WinHttpCloseHandleC = Int32 Function(Pointer<Void> hInternet);
typedef WinHttpCloseHandleDart = int Function(Pointer<Void> hInternet);

typedef GetLastErrorC = Uint32 Function();
typedef GetLastErrorDart = int Function();

/// WinHTTP 动态链接库加载类
class WinHttpLibrary {
  static DynamicLibrary? _winhttp;
  static DynamicLibrary? _kernel32;

  static DynamicLibrary get winhttp {
    _winhttp ??= DynamicLibrary.open('winhttp.dll');
    return _winhttp!;
  }

  static DynamicLibrary get kernel32 {
    _kernel32 ??= DynamicLibrary.open('kernel32.dll');
    return _kernel32!;
  }

  // WinHTTP 函数
  static final WinHttpOpenDart WinHttpOpen = winhttp.lookupFunction<WinHttpOpenC, WinHttpOpenDart>('WinHttpOpen');
  static final WinHttpConnectDart WinHttpConnect = winhttp.lookupFunction<WinHttpConnectC, WinHttpConnectDart>('WinHttpConnect');
  static final WinHttpOpenRequestDart WinHttpOpenRequest = winhttp.lookupFunction<WinHttpOpenRequestC, WinHttpOpenRequestDart>('WinHttpOpenRequest');
  static final WinHttpAddRequestHeadersDart WinHttpAddRequestHeaders = winhttp.lookupFunction<WinHttpAddRequestHeadersC, WinHttpAddRequestHeadersDart>('WinHttpAddRequestHeaders');
  static final WinHttpSetOptionDart WinHttpSetOption = winhttp.lookupFunction<WinHttpSetOptionC, WinHttpSetOptionDart>('WinHttpSetOption');
  static final WinHttpQueryHeadersDart WinHttpQueryHeaders = winhttp.lookupFunction<WinHttpQueryHeadersC, WinHttpQueryHeadersDart>('WinHttpQueryHeaders');
  static final WinHttpSendRequestDart WinHttpSendRequest = winhttp.lookupFunction<WinHttpSendRequestC, WinHttpSendRequestDart>('WinHttpSendRequest');
  static final WinHttpReceiveResponseDart WinHttpReceiveResponse = winhttp.lookupFunction<WinHttpReceiveResponseC, WinHttpReceiveResponseDart>('WinHttpReceiveResponse');
  static final WinHttpWebSocketCompleteUpgradeDart WinHttpWebSocketCompleteUpgrade = winhttp.lookupFunction<WinHttpWebSocketCompleteUpgradeC, WinHttpWebSocketCompleteUpgradeDart>('WinHttpWebSocketCompleteUpgrade');
  static final WinHttpWebSocketSendDart WinHttpWebSocketSend = winhttp.lookupFunction<WinHttpWebSocketSendC, WinHttpWebSocketSendDart>('WinHttpWebSocketSend');
  static final WinHttpWebSocketReceiveDart WinHttpWebSocketReceive = winhttp.lookupFunction<WinHttpWebSocketReceiveC, WinHttpWebSocketReceiveDart>('WinHttpWebSocketReceive');
  static final WinHttpWebSocketCloseDart WinHttpWebSocketClose = winhttp.lookupFunction<WinHttpWebSocketCloseC, WinHttpWebSocketCloseDart>('WinHttpWebSocketClose');
  static final WinHttpCloseHandleDart WinHttpCloseHandle = winhttp.lookupFunction<WinHttpCloseHandleC, WinHttpCloseHandleDart>('WinHttpCloseHandle');
  static final GetLastErrorDart GetLastError = kernel32.lookupFunction<GetLastErrorC, GetLastErrorDart>('GetLastError');
}

/// WebSocket 事件基类
sealed class WebSocketEvent {
  const WebSocketEvent();
}

/// 文本数据接收事件
class TextDataReceived extends WebSocketEvent {
  final String text;

  const TextDataReceived(this.text);

  @override
  String toString() => 'TextDataReceived(text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextDataReceived &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// 二进制数据接收事件
class BinaryDataReceived extends WebSocketEvent {
  final Uint8List data;

  const BinaryDataReceived(this.data);

  @override
  String toString() => 'BinaryDataReceived(data: ${data.length} bytes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BinaryDataReceived &&
          runtimeType == other.runtimeType &&
          _listEquals(data, other.data);

  @override
  int get hashCode => Object.hashAll(data);
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 关闭接收事件
class CloseReceived extends WebSocketEvent {
  final int? code;
  final String reason;

  const CloseReceived({this.code, this.reason = ''});

  @override
  String toString() => 'CloseReceived(code: $code, reason: $reason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloseReceived &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(code, reason);
}

/// WebSocket 异常
class WebSocketException implements Exception {
  final String message;

  const WebSocketException(this.message);

  @override
  String toString() => 'WebSocketException: $message';
}

/// WebSocket 连接已关闭异常
class WebSocketConnectionClosed extends WebSocketException {
  const WebSocketConnectionClosed() : super('WebSocket connection is closed');
}

/// 生成符合 RFC 6455 规范的 WebSocket 密钥
String _generateWebSocketKey() {
  final random = Random.secure();
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = random.nextInt(256);
  }
  return base64Encode(bytes);
}

/// 使用 Windows WinHTTP API 的 WebSocket 客户端
/// 兼容 package:web_socket 接口
class Win32WebSocket {
  Pointer<Void>? _session;
  Pointer<Void>? _connection;
  Pointer<Void>? _request;
  Pointer<Void>? _webSocket;

  bool _isClosed = true;
  bool _isClosing = false;

  final _eventController = StreamController<WebSocketEvent>.broadcast();

  /// 事件流 - 兼容 package:web_socket
  Stream<WebSocketEvent> get events => _eventController.stream;

  /// 创建新的 WebSocket 连接 - 兼容 package:web_socket
  static Future<Win32WebSocket> connect(Uri url, {Iterable<String>? protocols}) async {
    if (url.scheme != 'ws' && url.scheme != 'wss') {
      throw ArgumentError('URL scheme must be ws or wss: $url');
    }

    final ws = Win32WebSocket._();
    await ws._connect(url, protocols: protocols);
    return ws;
  }

  Win32WebSocket._();

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
        throw WebSocketException(
          'Failed to create WinHTTP session',
        );
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
        throw WebSocketException(
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
        throw WebSocketException(
          'Failed to create WinHTTP request',
        );
      }

      // 设置 WebSocket 请求头
      final wsHeaders = <String, String>{
        'Upgrade': 'websocket',
        'Connection': 'Upgrade',
        'Sec-WebSocket-Key': _generateWebSocketKey(),
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
          throw WebSocketException(
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
        throw WebSocketException(
          'Failed to send WebSocket request',
        );
      }

      // 接收响应
      final receiveResult = WinHttpLibrary.WinHttpReceiveResponse(_request!, nullptr);
      if (receiveResult == 0) {
        throw WebSocketException(
          'Failed to receive WebSocket response',
        );
      }

      // 升级到 WebSocket
      _webSocket = WinHttpLibrary.WinHttpWebSocketCompleteUpgrade(_request!, 0);
      if (_webSocket == nullptr || _webSocket!.address == 0) {
        throw WebSocketException(
          'Failed to upgrade to WebSocket',
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
  void sendText(String text) {
    if (_isClosed || _isClosing) {
      throw const WebSocketConnectionClosed();
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
  void sendBytes(Uint8List data) {
    if (_isClosed || _isClosing) {
      throw const WebSocketConnectionClosed();
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
  Future<void> close([int? code, String? reason]) async {
    if (_isClosed) {
      throw const WebSocketConnectionClosed();
    }

    if (_isClosing) {
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
      _eventController.add(CloseReceived(code: code ?? 1005, reason: reasonStr));
      await _eventController.close();
    }
  }

  /// 启动接收循环
  void _startReceiveLoop() {
    Future.doWhile(() async {
      if (_isClosed || _isClosing || _webSocket == null) {
        return false;
      }

      try {
        final buffer = calloc<Uint8>(4096);
        final bytesRead = calloc<Uint32>();
        final bufferType = calloc<Uint32>();

        try {
          final result = WinHttpLibrary.WinHttpWebSocketReceive(
            _webSocket!,
            buffer.cast<Void>(),
            4096,
            bytesRead,
            bufferType,
          );

          if (result != ERROR_SUCCESS && result != ERROR_INVALID_OPERATION) {
            // 连接可能已关闭
            if (!_isClosed && !_isClosing) {
              _eventController.add(const CloseReceived(code: 1006, reason: 'Connection error'));
            }
            await close(1006, 'Connection error');
            return false;
          }

          final type = bufferType.value;
          final count = bytesRead.value;

          if (type == WINHTTP_WEB_SOCKET_UTF8_MESSAGE_BUFFER_TYPE ||
              type == WINHTTP_WEB_SOCKET_UTF8_FRAGMENT_BUFFER_TYPE) {
            if (count > 0) {
              final data = buffer.asTypedList(count);
              final text = utf8.decode(data);
              _eventController.add(TextDataReceived(text));
            }
          } else if (type == WINHTTP_WEB_SOCKET_BINARY_MESSAGE_BUFFER_TYPE ||
              type == WINHTTP_WEB_SOCKET_BINARY_FRAGMENT_BUFFER_TYPE) {
            if (count > 0) {
              final data = Uint8List.fromList(buffer.asTypedList(count));
              _eventController.add(BinaryDataReceived(data));
            }
          } else if (type == WINHTTP_WEB_SOCKET_CLOSE_BUFFER_TYPE) {
            _eventController.add(const CloseReceived(code: 1000, reason: 'Server closed connection'));
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
          _eventController.add(CloseReceived(code: 1006, reason: e.toString()));
        }
        return false;
      }
    });
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

/// 兼容旧版 API 的别名
typedef WinHttpWebSocket = Win32WebSocket;
