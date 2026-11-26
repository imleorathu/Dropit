import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/util/device_type_ext.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onDetailsTap;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onChatTap,
    this.onDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final titleColor = theme.colorScheme.onSurface;

    return AppGlassDeviceCard(
      leading: DropitTile(
        size: 56,
        radius: 18,
        child: Icon(device.deviceType.icon, size: 27, color: iconColor),
      ),
      title: nameOverride ?? device.alias,
      subtitle: info ?? device.deviceModel ?? (device.ip != null ? 'Nearby device' : 'Remote device'),
      favorite: isFavorite,
      progress: progress,
      onTap: onTap,
      trailing: (onChatTap != null || onDetailsTap != null)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onChatTap != null)
                  IconButton(
                    tooltip: 'Local chat',
                    icon: Icon(usesAndroidMornye ? Symbols.chat_rounded : CupertinoIcons.chat_bubble, size: 19, color: titleColor),
                    onPressed: onChatTap,
                  ),
                if (onDetailsTap != null)
                  IconButton(
                    tooltip: 'Device details',
                    icon: Icon(usesAndroidMornye ? Symbols.info_rounded : CupertinoIcons.info_circle, size: 20, color: titleColor),
                    onPressed: onDetailsTap,
                  ),
              ],
            )
          : null,
    );
  }
}
