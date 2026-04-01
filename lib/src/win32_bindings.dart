// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:ffi';

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
