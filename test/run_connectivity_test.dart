#!/usr/bin/env dart
import 'dart:io';

/// 运行 WebSocket 连通性测试
/// 用法: dart test/run_connectivity_test.dart
void main() async {
  print('========================================');
  print('  WebSocket 连通性测试工具');
  print('========================================\n');

  // 检查是否在 Windows 上运行
  if (!Platform.isWindows) {
    print('错误: 此库只能在 Windows 平台上运行');
    exit(1);
  }

  print('正在启动测试...\n');

  // 运行测试
  final result = await Process.run(
    'dart',
    ['test', 'test/websocket_connectivity_test.dart', '--reporter=expanded'],
    workingDirectory: Directory.current.path,
    runInShell: true,
  );

  print(result.stdout);
  if (result.stderr.isNotEmpty) {
    print('错误输出:');
    print(result.stderr);
  }

  print('\n========================================');
  print('  测试完成');
  print('========================================');

  exit(result.exitCode);
}
