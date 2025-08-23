import 'package:flutter/services.dart';
import 'dart:io';

class WidgetAutoScrollService {
  static const MethodChannel _channel = MethodChannel('com.aim.aimNonsul/widget');
  
  static Future<void> setAutoScrollEnabled(bool enabled) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('setAutoScrollEnabled', {'enabled': enabled});
        print('Widget auto-scroll set to: $enabled');
      } catch (e) {
        print('Error setting auto-scroll: $e');
      }
    }
  }
  
  static Future<bool> getAutoScrollEnabled() async {
    if (Platform.isAndroid) {
      try {
        final bool enabled = await _channel.invokeMethod('getAutoScrollEnabled');
        return enabled;
      } catch (e) {
        print('Error getting auto-scroll status: $e');
        return true; // Default to enabled
      }
    }
    return true; // Default for non-Android platforms
  }
  
  static Future<void> toggleAutoScroll() async {
    final currentEnabled = await getAutoScrollEnabled();
    await setAutoScrollEnabled(!currentEnabled);
  }
}