import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

class LocationUtils {
  static const _platform = MethodChannel('location_picker');
  static Map<String, String> _appHeaderCache = {};
  static Future<Map<String, String>> getAppHeaders() async {
    if (_appHeaderCache.isEmpty) {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isIOS) {
        _appHeaderCache = {
          "X-Ios-Bundle-Identifier": packageInfo.packageName,
        };
      } else if (Platform.isAndroid) {
        try {
          _appHeaderCache = {
            "X-Android-Package": packageInfo.packageName,
            "X-Android-Cert": await _platform.invokeMethod(
                'getSigningCertSha1', packageInfo.packageName),
          };
        } on PlatformException {
          _appHeaderCache = {};
        }
      }
    }

    return _appHeaderCache;
  }
}
