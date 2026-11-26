import 'package:collection/collection.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/send_mode.dart';
import 'package:dropit_app/model/state/server/browser_session_state.dart';
import 'package:dropit_app/pages/chat_page.dart';
import 'package:dropit_app/pages/device_details_page.dart';
import 'package:dropit_app/pages/selected_files_page.dart';
import 'package:dropit_app/pages/tabs/send_tab_vm.dart';
import 'package:dropit_app/pages/troubleshoot_page.dart';
import 'package:dropit_app/provider/animation_provider.dart';
import 'package:dropit_app/provider/file_transfer_provider.dart';
import 'package:dropit_app/provider/network/nearby_devices_provider.dart';
import 'package:dropit_app/provider/network/scan_facade.dart';
import 'package:dropit_app/provider/network/send_provider.dart';
import 'package:dropit_app/provider/selection/selected_sending_files_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/util/favorites.dart';
import 'package:dropit_app/util/native/file_picker.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/widget/dialogs/send_mode_help_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/dropit/macos_liquid_glass.dart';
import 'package:dropit_app/widget/file_thumbnail.dart';
import 'package:dropit_app/widget/list_tile/device_list_tile.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/mornye/liquid_glass_motion.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/session_status.dart';
import 'package:dropit_isolates/util/file_size_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

final pickerOptions = FilePickerOption.getOptionsForPlatform();

class SendTab extends StatefulWidget {
  const SendTab();

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      provider: (ref) => sendTabVmProvider,
      init: (context) async => context.global.dispatchAsync(SendTabInitAction(context)), // ignore: discarded_futures
      builder: (context, vm) {
        final ref = context.ref;
        final theme = Theme.of(context);
        final fgColor = theme.colorScheme.onSurface;
        final subColor = theme.colorScheme.onSurfaceVariant;
        final query = _searchQuery.trim().toLowerCase();
        final devices = vm.nearbyDevices
            .where((d) => query.isEmpty || d.alias.toLowerCase().contains(query) || (d.ip ?? '').toLowerCase().contains(query))
            .toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 380;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : (width < 500 ? 20 : 36),
                width < 500 ? 18 : 22,
                compact ? 14 : (width < 500 ? 20 : 36),
                width < 760 ? 104 : 36,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropitHeading(
                        title: t.sendTab.title,
                        description: 'Select files and choose a nearby device to share.',
                      ),
                      const SizedBox(height: 16),
                      if (width < 620)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassInput(
                              controller: _searchController,
                              type: 'search',
                              placeholder: 'Filter nearby devices or IPs…',
                              onChanged: (val) => setState(() => _searchQuery = val),
                              onClear: () => setState(() => _searchQuery = ''),
                            ),
                            const SizedBox(height: 10),
                            AppGlassSegmented(
                              size: AppGlassButtonSize.md,
                              options: const [
                                AppGlassSegmentOption(label: 'Single'),
                                AppGlassSegmentOption(label: 'Multiple'),
                                AppGlassSegmentOption(label: 'Link'),
                              ],
                              value: SendMode.values.indexOf(vm.sendMode).clamp(0, 2),
                              onChanged: (idx) => vm.onTapSendMode(context, SendMode.values[idx]),
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GlassInput(
                                controller: _searchController,
                                type: 'search',
                                placeholder: 'Filter nearby devices or IPs…',
                                onChanged: (val) => setState(() => _searchQuery = val),
                                onClear: () => setState(() => _searchQuery = ''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 252,
                              child: AppGlassSegmented(
                                size: AppGlassButtonSize.md,
                                options: const [
                                  AppGlassSegmentOption(label: 'Single'),
                                  AppGlassSegmentOption(label: 'Multiple'),
                                  AppGlassSegmentOption(label: 'Link'),
                                ],
                                value: SendMode.values.indexOf(vm.sendMode).clamp(0, 2),
                                onChanged: (idx) => vm.onTapSendMode(context, SendMode.values[idx]),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: compact ? 16 : 22),
                      AppGlassDropZone(
                        highlighted: vm.selectedFiles.isNotEmpty,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : (width < 500 ? 18 : 26),
                          vertical: compact ? 16 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (vm.selectedFiles.isEmpty) ...[
                              const SizedBox(height: 4),
                              Center(
                                child: DropitTile(
                                  size: 64,
                                  radius: 24,
                                  child: Icon(
                                    usesAndroidMornye ? Symbols.file_copy_rounded : CupertinoIcons.doc_on_doc,
                                    size: 30,
                                    color: usesAndroidMornye ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Choose files to send',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: fgColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select items below${checkPlatformIsDesktop() ? ' or drag and drop files anywhere' : ''}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subColor, fontSize: 13.5),
                              ),
                              const SizedBox(height: 20),
                            ] else ...[
                              Row(
                                children: [
                                  Icon(
                                    usesAndroidMornye ? Symbols.file_copy_rounded : CupertinoIcons.doc_on_doc,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${vm.selectedFiles.length} items ready to go',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Clear selection',
                                    onPressed: () => ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction()),
                                    icon: Icon(usesAndroidMornye ? Symbols.close_rounded : CupertinoIcons.xmark_circle, size: 22),
                                  ),
                                ],
                              ),
                              Text(
                                vm.selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize,
                                style: TextStyle(color: subColor),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 76,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: vm.selectedFiles.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final file = vm.selectedFiles[index];
                                    return SizedBox(
                                      width: 240,
                                      child: AppGlassFileCard(
                                        thumbnail: SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: SmartFileThumbnail.fromCrossFile(file),
                                        ),
                                        title: file.name,
                                        subtitle: file.size.asReadableFileSize,
                                        onTap: () async => context.push(() => const SelectedFilesPage()),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: AppGlassButton(
                                  variant: AppGlassButtonVariant.tinted,
                                  size: AppGlassButtonSize.sm,
                                  icon: usesAndroidMornye ? Symbols.edit_rounded : CupertinoIcons.pencil,
                                  label: t.general.edit,
                                  onPressed: () async => context.push(() => const SelectedFilesPage()),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            if (usesAndroidMornye)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: compact ? 8 : 12,
                                runSpacing: compact ? 8 : 12,
                                children: [
                                  for (final option in pickerOptions)
                                    DropitPillButton(
                                      onPressed: () async => ref.global.dispatchAsync(PickFileAction(option: option, context: context)),
                                      icon: option.icon,
                                      label: option.label,
                                    ),
                                ],
                              )
                            else
                              LiquidGlassContainer(
                                spacing: compact ? 12.0 : 16.0,
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: compact ? 8 : 12,
                                  runSpacing: compact ? 8 : 12,
                                  children: [
                                    for (final option in pickerOptions)
                                      LiquidGlassMember(
                                        id: 'picker-${option.name}',
                                        groupId: 'send-picker',
                                        radius: 999,
                                        child: DropitPillButton(
                                          onPressed: () async => ref.global.dispatchAsync(PickFileAction(option: option, context: context)),
                                          icon: option.icon,
                                          label: option.label,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.sendTab.nearbyDevices,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: fgColor,
                                shadows: DropitHeading.floatingShadows(context),
                              ),
                            ),
                          ),
                          _ScanButton(ips: vm.localIps),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (devices.isEmpty)
                        DropitPanel(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Row(
                            children: [
                              DropitTile(
                                size: 48,
                                radius: 14,
                                child: Icon(
                                  usesAndroidMornye ? Symbols.wifi_tethering_rounded : CupertinoIcons.antenna_radiowaves_left_right,
                                  color: usesAndroidMornye ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No nearby devices found',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Make sure Dropit is open on the other device and connected to this Wi-Fi.',
                                      style: TextStyle(fontSize: 13, height: 1.4, color: subColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, layout) => Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final device in devices)
                                SizedBox(
                                  width: layout.maxWidth >= 650 ? (layout.maxWidth - 14) / 2 : layout.maxWidth,
                                  child: vm.sendMode == SendMode.multiple
                                      ? _MultiSendDeviceListTile(
                                          device: device,
                                          isFavorite: vm.favoriteDevices.findDevice(device) != null,
                                          nameOverride: vm.favoriteDevices.findDevice(device)?.alias,
                                          vm: vm,
                                        )
                                      : DeviceListTile(
                                          device: device,
                                          isFavorite: vm.favoriteDevices.findDevice(device) != null,
                                          nameOverride: vm.favoriteDevices.findDevice(device)?.alias,
                                          onChatTap: () async => context.push(() => ChatPage(peer: device)),
                                          onDetailsTap: () async => context.push(() => DeviceDetailsPage(device: device)),
                                          onTap: () async => vm.onTapDevice(context, device),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Connected Browsers',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: fgColor,
                                shadows: DropitHeading.floatingShadows(context),
                              ),
                            ),
                          ),
                          if (vm.browserSessions.sessions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${vm.browserSessions.sessions.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ConnectedBrowsersSection(vm: vm),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppGlassButton(
                            variant: AppGlassButtonVariant.glass,
                            size: AppGlassButtonSize.sm,
                            icon: usesAndroidMornye ? Symbols.link_rounded : CupertinoIcons.link,
                            label: 'Enter address',
                            onPressed: () async => vm.onTapAddress(context),
                          ),
                          AppGlassButton(
                            variant: AppGlassButtonVariant.glass,
                            size: AppGlassButtonSize.sm,
                            icon: usesAndroidMornye ? Symbols.star_rounded : CupertinoIcons.star,
                            label: 'Favorites',
                            onPressed: () async => vm.onTapFavorite(context),
                          ),
                          _SendModeButton(onSelect: (mode) async => vm.onTapSendMode(context, mode)),
                          AppGlassButton(
                            variant: AppGlassButtonVariant.clear,
                            size: AppGlassButtonSize.sm,
                            icon: usesAndroidMornye ? Symbols.help_rounded : CupertinoIcons.question_circle,
                            label: 'Need a hand?',
                            onPressed: () async => context.push(() => const TroubleshootPage()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Lists browsers that opened the sharing page and lets the user offer the
/// currently selected files to them.
class _ConnectedBrowsersSection extends StatelessWidget {
  final SendTabVm vm;

  const _ConnectedBrowsersSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final sessions = vm.browserSessions.sessions.values.toList()
      ..sort((a, b) {
        if (a.connected != b.connected) {
          return a.connected ? -1 : 1;
        }
        return a.browserName.toLowerCase().compareTo(b.browserName.toLowerCase());
      });

    if (sessions.isEmpty) {
      final port = vm.serverPort ?? vm.browserPort;
      final address = vm.localIps.isEmpty || port == null ? null : 'http://${vm.localIps.first}:$port';
      return _BrowserEmptyState(address: address);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 3 : (constraints.maxWidth >= 620 ? 2 : 1);
        const gap = 12.0;
        final itemWidth = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final session in sessions)
              SizedBox(
                width: itemWidth,
                child: _BrowserListTile(
                  session: session,
                  offer: vm.browserSessions.latestOfferForSession(session.sessionId),
                  onTap: () async => vm.onTapBrowser(context, session),
                  onDisconnect: () async => vm.onDisconnectBrowser(context, session),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BrowserEmptyState extends StatelessWidget {
  final String? address;

  const _BrowserEmptyState({required this.address});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.colorScheme.onSurface;
    final subColor = theme.colorScheme.onSurfaceVariant;

    return DropitPanel(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          DropitTile(
            size: 48,
            radius: 20,
            child: Icon(
              usesAndroidMornye ? Symbols.explore_rounded : CupertinoIcons.compass,
              size: 24,
              color: usesAndroidMornye ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No browser connected yet',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address == null
                      ? 'Open the Dropit sharing link in a browser on this network to send files without the app.'
                      : 'Open $address in a browser on this network to send files without the app.',
                  style: TextStyle(fontSize: 12.5, color: subColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserListTile extends StatelessWidget {
  final BrowserSession session;
  final BrowserOffer? offer;
  final Future<void> Function() onTap;
  final Future<void> Function() onDisconnect;

  const _BrowserListTile({
    required this.session,
    required this.offer,
    required this.onTap,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = switch (session.status) {
      BrowserConnectionStatus.connected => dark ? const Color(0xFF34C759) : const Color(0xFF0A662A),
      BrowserConnectionStatus.connecting => dark ? const Color(0xFFFF9F0A) : const Color(0xFF9A5B00),
      BrowserConnectionStatus.disconnected =>
        dark ? (theme.platform == TargetPlatform.macOS ? Colors.white : const Color(0xFF8E8E93)) : const Color(0xFF4C4C52),
    };

    final offer = this.offer;
    final showProgress =
        offer != null &&
        (offer.status == BrowserOfferStatus.accepted ||
            offer.status == BrowserOfferStatus.downloading ||
            offer.status == BrowserOfferStatus.completed);

    final badgeText = offer != null
        ? _offerLabel(offer)
        : (session.status == BrowserConnectionStatus.connecting ? 'Connecting' : (session.canReceive ? 'Ready to receive' : 'Offline'));

    return AppGlassDeviceCard(
      leading: DropitTile(
        size: 56,
        radius: 18,
        child: Icon(
          usesAndroidMornye ? Symbols.explore_rounded : CupertinoIcons.compass,
          size: 27,
          color: usesAndroidMornye ? theme.colorScheme.onSecondaryContainer : iconColor,
        ),
      ),
      title: session.browserName,
      subtitle: offer == null && session.canReceive
          ? '${session.description} · Tap to offer selected files'
          : (!session.canReceive ? '${session.description} · Waiting for reconnect…' : session.description),
      badge: badgeText,
      statusColor: offer?.status == BrowserOfferStatus.failed ? theme.colorScheme.error : statusColor,
      progress: showProgress ? offer.progress.clamp(0, 1) : null,
      onTap: session.canReceive ? () => onTap() : null,
      trailing: IconButton(
        tooltip: 'Disconnect browser',
        icon: Icon(usesAndroidMornye ? Symbols.close_rounded : CupertinoIcons.xmark_circle, size: 20, color: theme.colorScheme.onSurface),
        onPressed: () => onDisconnect(),
      ),
    );
  }

  String _offerLabel(BrowserOffer offer) {
    final count = offer.files.length;
    final fileLabel = count == 1 ? '1 file' : '$count files';
    switch (offer.status) {
      case BrowserOfferStatus.pending:
        return 'Waiting for acceptance of $fileLabel';
      case BrowserOfferStatus.accepted:
        return 'Accepted — starting download';
      case BrowserOfferStatus.downloading:
        return 'Downloading $fileLabel · ${(offer.progress * 100).round()}%';
      case BrowserOfferStatus.declined:
        return 'The browser declined $fileLabel';
      case BrowserOfferStatus.completed:
        return 'Download complete';
      case BrowserOfferStatus.cancelled:
        return 'Offer cancelled';
      case BrowserOfferStatus.failed:
        return offer.error ?? 'Transfer failed';
    }
  }
}

/// A button that opens a popup menu to select [T].
/// This is used for the scan button and the send mode button.
class _CircularPopupButton<T> extends StatelessWidget {
  final String tooltip;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget child;

  const _CircularPopupButton({
    required this.tooltip,
    required this.onSelected,
    required this.itemBuilder,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: Material(
        type: MaterialType.transparency,
        child: DividerTheme(
          data: DividerThemeData(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          child: PopupMenuButton(
            offset: const Offset(0, 40),
            onSelected: onSelected,
            tooltip: tooltip,
            itemBuilder: itemBuilder,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The scan button that uses [_CircularPopupButton].
class _ScanButton extends StatelessWidget {
  final List<String> ips;
  const _ScanButton({required this.ips});
  @override
  Widget build(BuildContext context) {
    final (favorites, scans) = context.ref.watch(nearbyDevicesProvider.select((s) => (s.runningFavoriteScan, s.runningIps)));
    final animate = context.ref.watch(animationProvider);
    final busy = favorites || scans.isNotEmpty;
    final indicator = busy && animate
        ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(
            usesAndroidMornye ? Symbols.refresh_rounded : CupertinoIcons.arrow_clockwise,
            size: 21,
            color: busy ? Theme.of(context).colorScheme.primary : null,
          );
    if (ips.length <= StartSmartScan.maxInterfaces) {
      return Semantics(
        label: t.sendTab.scan,
        button: true,
        child: AppGlassButton(
          variant: AppGlassButtonVariant.glass,
          size: AppGlassButtonSize.sm,
          loading: busy && animate,
          icon: usesAndroidMornye ? Symbols.refresh_rounded : CupertinoIcons.arrow_clockwise,
          onPressed: () async {
            context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
            await context.global.dispatchAsync(StartSmartScan());
          },
        ),
      );
    }
    return _CircularPopupButton<String>(
      tooltip: t.sendTab.scan,
      onSelected: (ip) async {
        context.redux(nearbyDevicesProvider).dispatch(ClearFoundDevicesAction());
        await context.global.dispatchAsync(StartLegacySubnetScan(subnets: [ip]));
      },
      itemBuilder: (_) => [for (final ip in ips) PopupMenuItem(value: ip, child: Text(ip))],
      child: Padding(padding: const EdgeInsets.all(12), child: indicator),
    );
  }
}

class _SendModeButton extends StatelessWidget {
  final void Function(SendMode mode) onSelect;

  const _SendModeButton({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _CircularPopupButton<int>(
      tooltip: t.sendTab.sendMode,
      onSelected: (mode) async {
        switch (mode) {
          case 0:
            onSelect(SendMode.single);
            break;
          case 1:
            onSelect(SendMode.multiple);
            break;
          case 2:
            onSelect(SendMode.link);
            break;
          case -1:
            await showDialog(context: context, builder: (_) => const SendModeHelpDialog());
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.single,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.single),
            ],
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer(
                builder: (context, ref) {
                  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
                  return Visibility(
                    visible: sendMode == SendMode.multiple,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: const Icon(Icons.check_circle),
                  );
                },
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.multiple),
            ],
          ),
        ),
        PopupMenuItem(
          value: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Icon(Icons.check_circle),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModes.link),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.help),
              ),
              const SizedBox(width: 10),
              Text(t.sendTab.sendModeHelp),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.settings),
      ),
    );
  }
}

/// An advanced list tile which shows the progress of the file transfer.
class _MultiSendDeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;
  final String? nameOverride;
  final SendTabVm vm;

  const _MultiSendDeviceListTile({
    required this.device,
    required this.isFavorite,
    required this.nameOverride,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final session = ref.watch(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
    final String? info;
    final double? progress;
    if (session != null) {
      final files = session.files.values.where((f) => f.token != null);
      final transferNotifier = ref.watch(fileTransferProvider);
      final currBytes = files.fold<int>(
        0,
        (prev, curr) => prev + ((transferNotifier.getProgress(sessionId: session.sessionId, fileId: curr.file.id) * curr.file.size).round()),
      );
      final totalBytes = files.fold<int>(0, (prev, curr) => prev + curr.file.size);
      progress = totalBytes == 0 ? 0 : currBytes / totalBytes;
      info = session.hashedFileCount < session.files.length
          ? t.sendPage.calculatingChecksum(curr: session.hashedFileCount, n: session.files.length)
          : session.status.humanString;
    } else {
      progress = null;
      info = null;
    }
    return DeviceListTile(
      device: device,
      info: info,
      progress: progress,
      isFavorite: isFavorite,
      nameOverride: nameOverride,
      onDetailsTap: () async => await context.push(() => DeviceDetailsPage(device: device)),
      onTap: () async => await vm.onTapDeviceMultiSend(context, device),
    );
  }
}

extension on SessionStatus {
  String? get humanString {
    switch (this) {
      case SessionStatus.waiting:
        return t.sendPage.waiting;
      case SessionStatus.recipientBusy:
        return t.sendPage.busy;
      case SessionStatus.declined:
        return t.sendPage.rejected;
      case SessionStatus.tooManyAttempts:
        return t.sendPage.tooManyAttempts;
      case SessionStatus.sending:
        return null;
      case SessionStatus.finished:
        return t.general.finished;
      case SessionStatus.finishedWithErrors:
        return t.progressPage.total.title.finishedError;
      case SessionStatus.canceledBySender:
        return t.progressPage.total.title.canceledSender;
      case SessionStatus.canceledByReceiver:
        return t.progressPage.total.title.canceledReceiver;
    }
  }
}
