import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:flutter/material.dart';

// Dropit brand mark shared by the settings and about screens.
class DropitLogo extends StatelessWidget {
  final bool withText;
  const DropitLogo({required this.withText});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const DropitMark(size: 100),
      if (withText) ...[
        const SizedBox(height: 18),
        const Text('Dropit', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.3)),
      ],
    ],
  );
}
