import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/pages/receive_history_page.dart';
import 'package:dropit_app/provider/local_ip_provider.dart';
import 'package:dropit_app/provider/network/server/server_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/dropit/macos_liquid_glass.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ReceiveTab extends StatelessWidget {
  const ReceiveTab();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch(settingsProvider);
    final server = context.watch(serverProvider);
    final ips = context.watch(localIpProvider.select((s) => s.localIps));
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 380;
        final heroSize = compact ? 200.0 : 260.0;
        final ringSizes = compact ? const [195.0, 146.0, 100.0] : const [230.0, 174.0, 120.0];
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : (width < 500 ? 20 : 36),
            width < 500 ? 18 : 28,
            compact ? 14 : (width < 500 ? 20 : 36),
            width < 760 ? 104 : 36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropitHeading(
                    title: t.receiveTab.title,
                    description: 'Visible to devices on the same Wi-Fi network.',
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  DropitPanel(
                    padding: EdgeInsets.all(compact ? 16 : 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        SizedBox(
                          width: heroSize,
                          height: compact ? 184 : 202,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (final diameter in ringSizes)
                                Container(
                                  width: diameter,
                                  height: diameter,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: diameter == ringSizes.last ? .24 : .12),
                                    ),
                                    gradient: RadialGradient(
                                      colors: [
                                        theme.colorScheme.primary.withValues(alpha: .06),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              DropitMark(size: compact ? 70 : 86),
                              Positioned(
                                right: compact ? 16 : 26,
                                top: compact ? 28 : 42,
                                child: _OrbitIcon(
                                  icon: usesAndroidMornye ? Symbols.description_rounded : CupertinoIcons.doc,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Positioned(
                                left: compact ? 16 : 25,
                                bottom: compact ? 24 : 38,
                                child: _OrbitIcon(
                                  icon: usesAndroidMornye ? Symbols.image_rounded : CupertinoIcons.photo,
                                  color: usesAndroidMornye ? theme.colorScheme.tertiary : const Color(0xFFAF68CB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          server?.alias ?? settings.alias,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.6),
                        ),
                        const SizedBox(height: 12),
                        if (usesAndroidMornye)
                          Material(
                            color: theme.colorScheme.secondaryContainer,
                            shape: const StadiumBorder(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: DropitStatus(online: server != null),
                            ),
                          )
                        else
                          AppLiquidGlass(
                            radius: 999,
                            blurEnabled: false,
                            refractionDepth: 0.14,
                            dispersion: 0.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: DropitStatus(online: server != null),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          server != null
                              ? 'Choose this device on the sender’s screen.'
                              : 'Check your network and receiver settings to get connected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 0.5,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              usesAndroidMornye
                                  ? (settings.https ? Symbols.verified_user_rounded : Symbols.gpp_maybe_rounded)
                                  : (settings.https ? CupertinoIcons.lock_shield : CupertinoIcons.exclamationmark_shield),
                              size: 19,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                settings.https
                                    ? 'Encrypted on your local network. No cloud in between.'
                                    : 'Encryption is off. Enable it in Settings for private transfers.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppGlassButton(
                        variant: AppGlassButtonVariant.glass,
                        size: AppGlassButtonSize.md,
                        icon: usesAndroidMornye ? Symbols.history_rounded : CupertinoIcons.clock,
                        label: 'Received files',
                        onPressed: () async => context.push(() => const ReceiveHistoryPage()),
                      ),
                      if (!usesAndroidMornye)
                        AppGlassButton(
                          variant: AppGlassButtonVariant.tinted,
                          size: AppGlassButtonSize.md,
                          icon: CupertinoIcons.sparkles,
                          label: 'Glass Controls',
                          onPressed: () => showGlassControlCenter(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropitPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Theme(
                      data: theme.copyWith(
                        dividerColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Connection details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        childrenPadding: const EdgeInsets.only(bottom: 14),
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SelectableText(
                              [
                                ...ips,
                                'Port ${server?.port ?? settings.port}',
                                'Multicast ${settings.multicastGroup}',
                              ].join('\n'),
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrbitIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _OrbitIcon({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    if (usesAndroidMornye) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: color, size: 22, fill: 1),
        ),
      );
    }
    return AppLiquidGlass(
      radius: 16,
      strongTint: true,
      refractionDepth: 0.28,
      dispersion: 1.8,
      smoothCorners: true,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
