import 'dart:async';

import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The widget-test renderer has no platform shader backend. Exercise the
  // production lens tree while individual fallback tests can still override
  // this hook explicitly.
  AppLiquidGlass.debugShaderFilterSupport = true;
  await testMain();
}
