// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'glass_quality.dart';

class AppGlassQualityMapper extends EnumMapper<AppGlassQuality> {
  AppGlassQualityMapper._();

  static AppGlassQualityMapper? _instance;
  static AppGlassQualityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AppGlassQualityMapper._());
    }
    return _instance!;
  }

  static AppGlassQuality fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  AppGlassQuality decode(dynamic value) {
    switch (value) {
      case r'liquid':
        return AppGlassQuality.liquid;
      case r'frosted':
        return AppGlassQuality.frosted;
      case r'flat':
        return AppGlassQuality.flat;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(AppGlassQuality self) {
    switch (self) {
      case AppGlassQuality.liquid:
        return r'liquid';
      case AppGlassQuality.frosted:
        return r'frosted';
      case AppGlassQuality.flat:
        return r'flat';
    }
  }
}

extension AppGlassQualityMapperExtension on AppGlassQuality {
  String toValue() {
    AppGlassQualityMapper.ensureInitialized();
    return MapperContainer.globals.toValue<AppGlassQuality>(this) as String;
  }
}

