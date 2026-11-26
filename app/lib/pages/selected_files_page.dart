import 'dart:convert';

import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/provider/selection/selected_sending_files_provider.dart';
import 'package:dropit_app/util/native/open_file.dart';
import 'package:dropit_app/util/ui/nav_bar_padding.dart';
import 'package:dropit_app/widget/dialogs/message_input_dialog.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/file_thumbnail.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:dropit_app/widget/mornye/app_glass_cards.dart';
import 'package:dropit_app/widget/responsive_list_view.dart';
import 'package:dropit_isolates/model/file_type.dart';
import 'package:dropit_isolates/util/file_size_helper.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SelectedFilesPage extends StatelessWidget {
  const SelectedFilesPage();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final selectedFiles = ref.watch(selectedSendingFilesProvider);

    return Scaffold(
      appBar: DropitAppBar(
        title: Text(t.sendTab.selection.title),
      ),
      body: ResponsiveListView.single(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        tabletPadding: const EdgeInsets.symmetric(horizontal: 15),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: 18),
            ),
            SliverToBoxAdapter(
              child: DropitPanel(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.sendTab.selection.files(files: selectedFiles.length),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.sendTab.selection.size(size: selectedFiles.fold(0, (prev, curr) => prev + curr.size).asReadableFileSize),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    AppGlassButton(
                      variant: AppGlassButtonVariant.tinted,
                      size: AppGlassButtonSize.sm,
                      destructive: true,
                      label: t.selectedFilesPage.deleteAll,
                      onPressed: () {
                        ref.redux(selectedSendingFilesProvider).dispatch(ClearSelectionAction());
                        context.popUntilRoot();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 14),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                childCount: selectedFiles.length,
                (context, index) {
                  final file = selectedFiles[index];

                  final String? message;
                  if (file.fileType == FileType.text && file.bytes != null) {
                    message = utf8.decode(file.bytes!);
                  } else {
                    message = null;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppGlassFileCard(
                      thumbnail: SmartFileThumbnail.fromCrossFile(file),
                      title: message != null ? '"${message.replaceAll('\n', ' ')}"' : file.name,
                      subtitle: file.size.asReadableFileSize,
                      onTap: file.path != null ? () async => openFile(context, file.fileType, file.path!) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (file.fileType == FileType.text && file.bytes != null)
                            IconButton(
                              tooltip: t.general.edit,
                              onPressed: () async {
                                final result = await showDialog<String>(
                                  context: context,
                                  builder: (_) => MessageInputDialog(initialText: message),
                                );
                                if (result != null) {
                                  ref.redux(selectedSendingFilesProvider).dispatch(UpdateMessageAction(message: result, index: index));
                                }
                              },
                              icon: const Icon(Icons.edit),
                            ),
                          IconButton(
                            tooltip: t.general.delete,
                            onPressed: () {
                              final currCount = ref.read(selectedSendingFilesProvider).length;
                              ref.redux(selectedSendingFilesProvider).dispatch(RemoveSelectedFileAction(index));
                              if (currCount == 1) {
                                context.popUntilRoot();
                              }
                            },
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 15 + getNavBarPadding(context)),
            ),
          ],
        ),
      ),
    );
  }
}
