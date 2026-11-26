import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/favorite_device.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class FavoriteDeleteDialog extends StatelessWidget {
  final FavoriteDevice favorite;

  const FavoriteDeleteDialog(this.favorite);

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.favoriteDeleteDialog.title),
      content: Text(t.dialogs.favoriteDeleteDialog.content(name: favorite.alias)),
      actions: [
        AppGlassButton(
          variant: AppGlassButtonVariant.clear,
          size: AppGlassButtonSize.sm,
          label: t.general.cancel,
          onPressed: () => context.pop(),
        ),
        AppGlassButton(
          variant: AppGlassButtonVariant.filled,
          size: AppGlassButtonSize.sm,
          destructive: true,
          label: t.general.delete,
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }
}
