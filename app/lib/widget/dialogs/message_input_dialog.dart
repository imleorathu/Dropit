import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';

class MessageInputDialog extends StatefulWidget {
  final String? initialText;

  const MessageInputDialog({this.initialText});

  @override
  State<MessageInputDialog> createState() => _MessageInputDialogState();
}

class _MessageInputDialogState extends State<MessageInputDialog> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.messageInput.title),
      content: TextFormField(
        controller: _textController,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        autofocus: true,
      ),
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
          label: t.general.confirm,
          onPressed: () => context.pop(_textController.text),
        ),
      ],
    );
  }
}
