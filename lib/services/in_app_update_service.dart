import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InAppUpdateService {
  static const MethodChannel _channel = MethodChannel('in_app_update');

  /// 인앱 업데이트 가능 여부 확인
  static Future<bool> isUpdateAvailable() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('isUpdateAvailable');
      return result;
    } catch (e) {
      debugPrint('인앱 업데이트 확인 중 오류: $e');
      return false;
    }
  }

  /// 유연한 업데이트 (Flexible Update) 시작
  /// 사용자가 앱을 계속 사용할 수 있음
  static Future<bool> startFlexibleUpdate() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('startFlexibleUpdate');
      return result;
    } catch (e) {
      debugPrint('유연한 업데이트 시작 중 오류: $e');
      return false;
    }
  }

  /// 즉시 업데이트 (Immediate Update) 시작
  /// 앱이 재시작됨
  static Future<bool> startImmediateUpdate() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _channel.invokeMethod('startImmediateUpdate');
      return result;
    } catch (e) {
      debugPrint('즉시 업데이트 시작 중 오류: $e');
      return false;
    }
  }

  /// 유연한 업데이트 완료 후 앱 재시작
  static Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('completeFlexibleUpdate');
    } catch (e) {
      debugPrint('유연한 업데이트 완료 중 오류: $e');
    }
  }

  /// 업데이트 상태 리스너 등록
  static void setUpdateStateListener(Function(int state) onStateUpdate) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUpdateState') {
        onStateUpdate(call.arguments);
      }
    });
  }

  /// 업데이트 다이얼로그 표시
  static Future<void> showUpdateDialog(BuildContext context) async {
    final bool isAvailable = await isUpdateAvailable();
    
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업데이트할 수 있는 버전이 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('앱 업데이트'),
          content: const Text('새로운 버전이 있습니다. 업데이트하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await startImmediateUpdate();
              },
              child: const Text('지금 업데이트'),
            ),
          ],
        );
      },
    );
  }

  /// 백그라운드에서 업데이트 확인 및 알림
  static Future<void> checkForUpdatesInBackground(BuildContext context) async {
    final bool isAvailable = await isUpdateAvailable();
    
    if (isAvailable) {
      // 사용자에게 업데이트 알림 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('새로운 버전이 있습니다!'),
          action: SnackBarAction(
            label: '업데이트',
            onPressed: () => showUpdateDialog(context),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
