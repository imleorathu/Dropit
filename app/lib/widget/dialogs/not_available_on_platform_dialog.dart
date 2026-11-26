import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/util/platform_strings.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class NotAvailableOnPlatformDialog extends StatelessWidget {
  final List<TargetPlatform> platforms;

  const NotAvailableOnPlatformDialog({required this.platforms});

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.notAvailableOnPlatform.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dialogs.notAvailableOnPlatform.content),
          const SizedBox(height: 10),
          ...platforms.map((p) {
            return Text('- ${p.humanName}');
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.close),
        ),
      ],
    );
  }
}
