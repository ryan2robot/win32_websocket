import 'dart:ffi';
import 'dart:io';

// 简单的 WinHTTP 测试
void main() {
  print('Windows version: ${Platform.operatingSystemVersion}');
  print('Testing WinHTTP...');

  // 加载 winhttp.dll
  final winhttp = DynamicLibrary.open('winhttp.dll');
  print('winhttp.dll loaded');

  // 尝试查找 WebSocket 函数
  try {
    final completeUpgrade = winhttp.lookup('WinHttpWebSocketCompleteUpgrade');
    print('WinHttpWebSocketCompleteUpgrade found at: $completeUpgrade');
  } catch (e) {
    print('WinHttpWebSocketCompleteUpgrade NOT found: $e');
  }

  // 尝试查找 SetTimeouts
  try {
    final setTimeouts = winhttp.lookup('WinHttpSetTimeouts');
    print('WinHttpSetTimeouts found at: $setTimeouts');
  } catch (e) {
    print('WinHttpSetTimeouts NOT found: $e');
  }

  print('Done');
}
