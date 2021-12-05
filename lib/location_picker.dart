
import 'dart:async';

import 'package:flutter/services.dart';

class LocationPicker {
  static const MethodChannel _channel = MethodChannel('location_picker');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
