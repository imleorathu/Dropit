import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class ErrorDialog extends StatelessWidget {
  final String error;

  const ErrorDialog({required this.error, super.key});

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.errorDialog.title),
      content: SelectableText(error),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.close),
        ),
      ],
    );
  }
}
