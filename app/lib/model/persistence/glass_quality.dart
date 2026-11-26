import 'package:dart_mappable/dart_mappable.dart';

part 'glass_quality.mapper.dart';

/// Rendering quality tier for optical Liquid Glass surfaces.
@MappableEnum()
enum AppGlassQuality {
  /// Full optical GPU fragment shader with refraction, dispersion, and specular rim.
  liquid,

  /// Quantized backdrop blur + translucent tint + painted rim (reduced GPU cost).
  frosted,

  /// Solid / high-contrast surface without backdrop reads or blur.
  flat,
}
