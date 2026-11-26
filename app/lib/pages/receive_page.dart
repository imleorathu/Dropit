import 'dart:async';

import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/color_mode.dart';
import 'package:dropit_app/pages/receive_options_page.dart';
import 'package:dropit_app/pages/verify_page.dart';
import 'package:dropit_app/pages/web_share_page.dart';
import 'package:dropit_app/provider/favorites_provider.dart';
import 'package:dropit_app/provider/selection/selected_receiving_files_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/util/favorites.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/util/native/taskbar_helper.dart';
import 'package:dropit_app/util/ui/snackbar.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/dto/file_dto.dart';
import 'package:dropit_isolates/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

class ReceivePageVm {
  final SessionStatus? status;
  final Device sender;

  /// Show verify button and device model.
  final bool showSenderInfo;
  final List<FileDto> files;
  final String? message;
  final bool isLink;
  final void Function() onAccept;
  final void Function() onDecline;
  final void Function() onClose;

  ReceivePageVm({
    required this.status,
    required this.sender,
    required this.showSenderInfo,
    required this.files,
    required this.message,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  }) : isLink = message != null && !message.trim().contains(RegExp(r'\s')) && (Uri.tryParse(message.trim())?.isAbsolute ?? false);
}

class ReceivePage extends StatefulWidget {
  final ViewProvider<ReceivePageVm> vm;

  const ReceivePage(this.vm);

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> with Refena {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch(
      widget.vm,
      listener: (prev, next) {
        if (prev.status != next.status) {
          // ignore: discarded_futures
          TaskbarHelper.visualizeStatus(next.status);
        }
      },
    );

    if (vm.status == null && vm.message == null) {
      return const Scaffold(
        body: SizedBox(),
      );
    }

    final senderFavoriteEntry = ref.watch(favoritesProvider.select((state) => state.findDevice(vm.sender)));

    return ViewModelBuilder(
      provider: (ref) => widget.vm,
      dispose: (ref) {
        ref.dispose(widget.vm);
        unawaited(TaskbarHelper.clearProgressBar());
      },
      builder: (context, vm) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              vm.onDecline();
            }
          },
          canPop: true,
          child: Scaffold(
            appBar: const DropitAppBar(title: Text('Incoming drop')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        const DropitHeading(
                          title: 'Incoming Transfer',
                          description: 'Review the sender and incoming files.',
                        ),
                        const SizedBox(height: 28),
                        DropitPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(child: DropitMark(size: 64)),
                              const SizedBox(height: 24),
                              Text(
                                senderFavoriteEntry?.alias ?? vm.sender.alias,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.5),
                              ),
                              if (vm.showSenderInfo && vm.sender.deviceModel != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  vm.sender.deviceModel!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Text(
                                vm.message != null
                                    ? (vm.isLink ? t.receivePage.subTitleLink : t.receivePage.subTitleMessage)
                                    : t.receivePage.subTitle(n: vm.files.length),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (vm.showSenderInfo) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: !vm.sender.https
                                          ? null
                                          : () async =>
                                                context.push(() => VerifyPage(fingerprint: CombinedFingerprint.load(context, vm.sender.fingerprint))),
                                      icon: const Icon(Icons.verified_user_outlined, size: 18),
                                      label: Text(t.verifyPage.title),
                                    ),
                                    if (vm.message == null)
                                      TextButton.icon(
                                        onPressed: () async => context.push(() => ReceiveOptionsPage(vm)),
                                        icon: const Icon(Icons.tune, size: 18),
                                        label: Text(t.receiveOptionsPage.title),
                                      ),
                                  ],
                                ),
                              ],
                              if (vm.message != null) ...[
                                const SizedBox(height: 16),
                                DropitSurface(
                                  radius: 18,
                                  tonal: true,
                                  padding: const EdgeInsets.all(18),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 240),
                                    child: SingleChildScrollView(child: SelectableText(vm.message!)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 10,
                                  children: [
                                    AppGlassButton(
                                      variant: AppGlassButtonVariant.glass,
                                      size: AppGlassButtonSize.md,
                                      icon: Icons.copy,
                                      label: t.general.copy,
                                      onPressed: () {
                                        unawaited(Clipboard.setData(ClipboardData(text: vm.message!)));
                                        if (checkPlatformIsDesktop()) context.showSnackBar(t.general.copiedToClipboard);
                                        vm.onAccept();
                                        context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
                                      },
                                    ),
                                    if (vm.isLink)
                                      AppGlassButton(
                                        variant: AppGlassButtonVariant.filled,
                                        size: AppGlassButtonSize.md,
                                        icon: Icons.open_in_new,
                                        label: t.general.open,
                                        onPressed: () {
                                          unawaited(launchUrl(Uri.parse(vm.message!), mode: LaunchMode.externalApplication));
                                          vm.onAccept();
                                          context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
                                        },
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),
                              _Actions(vm),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  final ReceivePageVm vm;

  const _Actions(this.vm);

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedReceivingFilesProvider);
    final colorMode = context.watch(settingsProvider.select((state) => state.colorMode));

    if (vm.message != null) {
      return Center(
        child: AppGlassButton(
          variant: AppGlassButtonVariant.clear,
          size: AppGlassButtonSize.md,
          icon: Icons.close,
          label: t.general.close,
          onPressed: () {
            vm.onAccept();
            context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
          },
        ),
      );
    }

    if (vm.status == SessionStatus.canceledBySender) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              t.receivePage.canceled,
              style: TextStyle(color: Theme.of(context).colorScheme.warning),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: AppGlassButton(
              variant: AppGlassButtonVariant.glass,
              size: AppGlassButtonSize.md,
              icon: Icons.check_circle,
              label: t.general.close,
              onPressed: () {
                vm.onClose();
                context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            AppGlassButton(
              variant: AppGlassButtonVariant.tintedFilled,
              size: AppGlassButtonSize.md,
              destructive: colorMode != ColorMode.yaru,
              icon: Icons.close,
              label: t.general.decline,
              onPressed: () {
                vm.onDecline();
                context.global.dispatch(NavigateAction.popUntil<WebSharePage>());
              },
            ),
            AppGlassButton(
              variant: AppGlassButtonVariant.filled,
              size: AppGlassButtonSize.md,
              icon: Icons.check_circle,
              label: t.general.accept,
              onPressed: selectedFiles.isEmpty ? null : () => vm.onAccept(),
            ),
          ],
        ),
      ],
    );
  }
}
