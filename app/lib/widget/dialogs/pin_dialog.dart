import 'package:dropit_app/config/theme.dart';
import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_app/widget/mornye/app_glass_button.dart';
import 'package:flutter/material.dart';
import 'package:nanoid2/nanoid2.dart';
import 'package:routerino/routerino.dart';

class PinDialog extends StatefulWidget {
  final String? pin;
  final bool showInvalidPin;
  final bool obscureText;
  final bool generateRandom;

  const PinDialog({
    this.pin,
    required this.obscureText,
    this.showInvalidPin = false,
    this.generateRandom = false,
    super.key,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.pin ?? (widget.generateRandom ? nanoid(alphabet: Alphabet.noDoppelganger, length: 6) : '');
  }

  @override
  Widget build(BuildContext context) {
    return DropitAlertDialog(
      title: Text(t.dialogs.pin.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _textController,
            autofocus: true,
            obscureText: widget.obscureText,
            onFieldSubmitted: (value) => context.pop(value),
          ),
          if (widget.showInvalidPin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.web.invalidPin,
                style: TextStyle(color: Theme.of(context).colorScheme.warning),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
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
