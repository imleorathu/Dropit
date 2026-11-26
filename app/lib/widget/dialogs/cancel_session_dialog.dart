import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dialogs/custom_bottom_sheet.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class CancelSessionDialog extends StatelessWidget {
  const CancelSessionDialog();

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.cancelSession.title,
      description: t.dialogs.cancelSession.content,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppGlassButton(
            variant: AppGlassButtonVariant.glass,
            size: AppGlassButtonSize.sm,
            label: t.general.continueStr,
            onPressed: () => context.pop(false),
          ),
          AppGlassButton(
            variant: AppGlassButtonVariant.tintedFilled,
            size: AppGlassButtonSize.sm,
            destructive: true,
            icon: Icons.close,
            label: t.general.cancel,
            onPressed: () => context.pop(true),
          ),
        ],
      ),
    );
  }
}
