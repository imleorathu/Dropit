import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class HistoryClearDialog extends StatelessWidget {
  const HistoryClearDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.historyClearDialog.title),
      content: Text(t.dialogs.historyClearDialog.content),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
        AppGlassButton(
          variant: AppGlassButtonVariant.tintedFilled,
          size: AppGlassButtonSize.sm,
          destructive: true,
          label: t.general.delete,
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }
}
