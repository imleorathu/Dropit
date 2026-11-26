import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/device_info_result.dart';
import 'package:flutter/foundation.dart';
// ignore: implementation_imports
import 'package:slang/src/builder/model/enums.dart';
// ignore: implementation_imports
import 'package:slang/src/builder/utils/string_extensions.dart';

Future<DeviceInfoResult> getDeviceInfo() async {
  final plugin = DeviceInfoPlugin();
  final DeviceType deviceType;
  String? deviceModel;
  int? androidSdkInt;

  if (kIsWeb) {
    deviceType = DeviceType.web;
    try {
      final deviceInfo = await plugin.webBrowserInfo.timeout(const Duration(seconds: 3));
      deviceModel = deviceInfo.browserName.humanName;
    } catch (_) {
      deviceModel = 'Web Browser';
    }
  } else {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        deviceType = DeviceType.mobile;
        break;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        deviceType = DeviceType.desktop;
        break;
    }

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final deviceInfo = await plugin.androidInfo.timeout(const Duration(seconds: 3));
          final model = deviceInfo.model.trim();
          final brand = deviceInfo.brand.trim();
          deviceModel = model.isNotEmpty ? model : brand.toCase(CaseStyle.pascal);
          androidSdkInt = deviceInfo.version.sdkInt;
          break;
        case TargetPlatform.iOS:
          final deviceInfo = await plugin.iosInfo.timeout(const Duration(seconds: 3));
          deviceModel = deviceInfo.name.isNotEmpty && deviceInfo.name != 'iPhone'
              ? deviceInfo.name
              : (deviceInfo.model.isNotEmpty ? deviceInfo.model : deviceInfo.localizedModel);
          break;
        case TargetPlatform.linux:
          final deviceInfo = await plugin.linuxInfo.timeout(const Duration(seconds: 3));
          deviceModel = deviceInfo.prettyName.isNotEmpty ? deviceInfo.prettyName : 'Linux';
          break;
        case TargetPlatform.macOS:
          final deviceInfo = await plugin.macOsInfo.timeout(const Duration(seconds: 3));
          deviceModel = deviceInfo.computerName.isNotEmpty ? deviceInfo.computerName : 'macOS';
          break;
        case TargetPlatform.windows:
          final deviceInfo = await plugin.windowsInfo.timeout(const Duration(seconds: 3));
          deviceModel = deviceInfo.computerName.isNotEmpty ? deviceInfo.computerName : 'Windows';
          break;
        case TargetPlatform.fuchsia:
          deviceModel = 'Fuchsia';
          break;
      }
    } catch (_) {
      deviceModel ??= defaultTargetPlatform.name.toCase(CaseStyle.pascal);
    }
  }

  return DeviceInfoResult(
    deviceType: deviceType,
    deviceModel: deviceModel,
    androidSdkInt: androidSdkInt,
  );
}

/// Returns the actual hardware or system device name instead of random fruit aliases.
Future<String> getActualDeviceName() async {
  final plugin = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final deviceInfo = await plugin.webBrowserInfo.timeout(const Duration(seconds: 2));
      return deviceInfo.browserName.humanName ?? 'Web Browser';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final deviceInfo = await plugin.androidInfo.timeout(const Duration(seconds: 2));
        var model = deviceInfo.model.trim();
        final brand = deviceInfo.brand.trim();
        if (model.toLowerCase().contains('sdk_gphone') || model.toLowerCase().contains('emulator')) {
          model = 'Pixel 7';
        }
        if (model.isNotEmpty) {
          if (brand.isNotEmpty && !model.toLowerCase().contains(brand.toLowerCase()) && !model.startsWith('Pixel')) {
            final brandName = brand[0].toUpperCase() + brand.substring(1).toLowerCase();
            return '$brandName $model';
          }
          return model;
        }
        return brand.isNotEmpty ? brand : 'Android Device';

      case TargetPlatform.iOS:
        final deviceInfo = await plugin.iosInfo.timeout(const Duration(seconds: 2));
        final name = deviceInfo.name.trim();
        if (name.isNotEmpty && name != 'iPhone' && name != 'iPad') {
          return name;
        }
        final model = deviceInfo.model.trim();
        return model.isNotEmpty ? model : (name.isNotEmpty ? name : 'iPhone');

      case TargetPlatform.macOS:
        final deviceInfo = await plugin.macOsInfo.timeout(const Duration(seconds: 2));
        final compName = deviceInfo.computerName.trim();
        if (compName.isNotEmpty) {
          return compName;
        }
        final host = deviceInfo.hostName.trim();
        if (host.isNotEmpty) {
          return host;
        }
        return 'Mac';

      case TargetPlatform.windows:
        final deviceInfo = await plugin.windowsInfo.timeout(const Duration(seconds: 2));
        final compName = deviceInfo.computerName.trim();
        if (compName.isNotEmpty) {
          return compName;
        }
        return 'Windows PC';

      case TargetPlatform.linux:
        final deviceInfo = await plugin.linuxInfo.timeout(const Duration(seconds: 2));
        final prettyName = deviceInfo.prettyName.trim();
        if (prettyName.isNotEmpty) {
          return prettyName;
        }
        return Platform.localHostname.isNotEmpty ? Platform.localHostname : 'Linux Device';

      case TargetPlatform.fuchsia:
        return 'Fuchsia Device';
    }
  } catch (_) {
    // Fallback on timeout or platform channel error
  }

  try {
    final hostname = Platform.localHostname.trim();
    if (hostname.isNotEmpty && hostname != 'localhost') {
      return hostname;
    }
  } catch (_) {}

  return defaultTargetPlatform.name.toCase(CaseStyle.pascal);
}

extension on BrowserName {
  String? get humanName {
    switch (this) {
      case BrowserName.firefox:
        return 'Firefox';
      case BrowserName.samsungInternet:
        return 'Samsung Internet';
      case BrowserName.opera:
        return 'Opera';
      case BrowserName.msie:
        return 'Internet Explorer';
      case BrowserName.edge:
        return 'Microsoft Edge';
      case BrowserName.chrome:
        return 'Google Chrome';
      case BrowserName.safari:
        return 'Safari';
      case BrowserName.unknown:
        return null;
    }
  }
}
