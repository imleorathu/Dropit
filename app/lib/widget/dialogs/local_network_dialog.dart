import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dialogs/custom_bottom_sheet.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:system_settings_2/system_settings_2.dart';

class LocalNetworkDialog extends StatelessWidget {
  const LocalNetworkDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomBottomSheet(
      title: t.dialogs.localNetworkUnauthorized.title,
      description: t.dialogs.localNetworkUnauthorized.description,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppGlassButton(
            variant: AppGlassButtonVariant.clear,
            label: t.general.close,
            onPressed: () => context.pop(),
          ),
          AppGlassButton(
            variant: AppGlassButtonVariant.filled,
            icon: Icons.settings,
            label: t.dialogs.localNetworkUnauthorized.gotoSettings,
            onPressed: () async => SystemSettings.app(),
          ),
        ],
      ),
    );
  }
}
