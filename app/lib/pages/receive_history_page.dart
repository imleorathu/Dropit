import 'dart:io';

import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/model/persistence/receive_history_entry.dart';
import 'package:dropit_app/pages/receive_page.dart';
import 'package:dropit_app/provider/receive_history_provider.dart';
import 'package:dropit_app/provider/settings_provider.dart';
import 'package:dropit_app/theme/android_mornye_theme.dart';
import 'package:dropit_app/util/native/directories.dart';
import 'package:dropit_app/util/native/open_file.dart';
import 'package:dropit_app/util/native/open_folder.dart';
import 'package:dropit_app/util/native/platform_check.dart';
import 'package:dropit_app/widget/dialogs/file_info_dialog.dart';
import 'package:dropit_app/widget/dialogs/history_clear_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/file_thumbnail.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/responsive_list_view.dart';
import 'package:dropit_isolates/model/device.dart';
import 'package:dropit_isolates/model/session_status.dart';
import 'package:dropit_isolates/util/file_size_helper.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum _EntryOption {
  open,
  showInFolder,
  info,
  delete
  ;

  String get label {
    return switch (this) {
      _EntryOption.open => t.receiveHistoryPage.entryActions.open,
      _EntryOption.showInFolder => t.receiveHistoryPage.entryActions.showInFolder,
      _EntryOption.info => t.receiveHistoryPage.entryActions.info,
      _EntryOption.delete => t.receiveHistoryPage.entryActions.deleteFromHistory,
    };
  }
}

const _optionsAll = _EntryOption.values;
final _optionsWithoutOpen = [_EntryOption.info, _EntryOption.delete];

class ReceiveHistoryPage extends StatelessWidget {
  const ReceiveHistoryPage({super.key});

  Future<void> _openFile(
    BuildContext context,
    ReceiveHistoryEntry entry,
    Dispatcher<ReceiveHistoryService, List<ReceiveHistoryEntry>> dispatcher,
  ) async {
    if (entry.path != null) {
      await openFile(
        context,
        entry.fileType,
        entry.path!,
        onDeleteTap: () => dispatcher.dispatchAsync(RemoveHistoryEntryAction(entry.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch(receiveHistoryProvider);

    return Scaffold(
      appBar: DropitAppBar(
        title: Text(t.receiveHistoryPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 15),
                AppGlassButton(
                  variant: AppGlassButtonVariant.glass,
                  size: AppGlassButtonSize.sm,
                  icon: Icons.folder,
                  label: t.receiveHistoryPage.openFolder,
                  onPressed: checkPlatform([TargetPlatform.iOS])
                      ? null
                      : () async {
                          // ignore: use_build_context_synchronously
                          final destination = context.read(settingsProvider).destination ?? await getDefaultDestinationDirectory();
                          await openFolder(folderPath: destination);
                        },
                ),
                const SizedBox(width: 14),
                AppGlassButton(
                  variant: AppGlassButtonVariant.tinted,
                  size: AppGlassButtonSize.sm,
                  destructive: true,
                  icon: Icons.delete,
                  label: t.receiveHistoryPage.deleteHistory,
                  onPressed: entries.isEmpty
                      ? null
                      : () async {
                          final result = await showDialog(
                            context: context,
                            builder: (_) => const HistoryClearDialog(),
                          );

                          if (context.mounted && result == true) {
                            await context.redux(receiveHistoryProvider).dispatchAsync(RemoveAllHistoryEntriesAction());
                          }
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 60, 15, 0),
              child: DropitPanel(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(t.receiveHistoryPage.empty, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                ),
              ),
            )
          else
            ...entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                child: DropitSurface(
                  radius: 22,
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    splashColor: usesAndroidMornye ? null : Colors.transparent,
                    splashFactory: usesAndroidMornye ? null : NoSplash.splashFactory,
                    highlightColor: usesAndroidMornye ? null : Colors.transparent,
                    hoverColor: usesAndroidMornye ? null : Colors.transparent,
                    onTap: entry.path != null || entry.isMessage
                        ? () async {
                            if (entry.isMessage) {
                              final vm = ViewProvider((ref) {
                                return ReceivePageVm(
                                  status: SessionStatus.waiting,
                                  sender: Device(
                                    signalingId: null,
                                    ip: '0.0.0.0',
                                    version: '1.0.0',
                                    port: 8080,
                                    https: false,
                                    fingerprint: 'fingerprint',
                                    alias: entry.senderAlias,
                                    deviceModel: 'deviceModel',
                                    deviceType: DeviceType.web,
                                    download: true,
                                    channels: const [],
                                  ),
                                  showSenderInfo: false,
                                  files: [],
                                  message: entry.fileName,
                                  onAccept: () {},
                                  onDecline: () {},
                                  onClose: () {},
                                );
                              });

                              // ignore: unawaited_futures
                              context.push(() => ReceivePage(vm));
                              return;
                            }

                            await _openFile(context, entry, context.redux(receiveHistoryProvider));
                          }
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FilePathThumbnail(
                          path: entry.path,
                          fileType: entry.fileType,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.fileName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.timestampString} - ${entry.fileSize.asReadableFileSize} - ${entry.senderAlias}',
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<_EntryOption>(
                          onSelected: (_EntryOption item) async {
                            switch (item) {
                              case _EntryOption.open:
                                await _openFile(context, entry, context.redux(receiveHistoryProvider));
                                break;
                              case _EntryOption.showInFolder:
                                if (entry.path != null) {
                                  await openFolder(
                                    folderPath: File(entry.path!).parent.path,
                                    fileName: path.basename(entry.path!),
                                  );
                                }
                                break;
                              case _EntryOption.info:
                                // ignore: use_build_context_synchronously
                                await showDialog(
                                  context: context,
                                  builder: (_) => FileInfoDialog(entry: entry),
                                );
                                break;
                              case _EntryOption.delete:
                                // ignore: use_build_context_synchronously
                                await context.redux(receiveHistoryProvider).dispatchAsync(RemoveHistoryEntryAction(entry.id));
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return (entry.path != null ? _optionsAll : _optionsWithoutOpen).map((e) {
                              return PopupMenuItem<_EntryOption>(
                                value: e,
                                child: Text(e.label),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
