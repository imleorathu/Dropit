// Dropit change: independently authored connection-help UI.
// The discovery and HTTPS transfer implementation is unchanged.
import 'package:dropit_app/widget/dropit/dropit_alert_dialog.dart';
import 'package:dropit_isolates/constants.dart';
import 'package:flutter/material.dart';

Future<void> showDropitConnectionHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => DropitAlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi_tethering),
          SizedBox(width: 12),
          Flexible(child: Text('Connect your devices')),
        ],
      ),
      content: const SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share files without an internet connection, using your local network.'),
              SizedBox(height: 16),
              _HelpRow(Icons.router, 'Use the same Wi-Fi or local network on both devices.'),
              SizedBox(height: 12),
              _HelpRow(Icons.lock_outline, 'Accept incoming transfers on the receiving device.'),
              SizedBox(height: 12),
              _HelpRow(Icons.shield_outlined, 'Allow local network permissions in Android or iOS settings.'),
              SizedBox(height: 12),
              _HelpRow(Icons.settings_ethernet, 'Allow TCP and UDP port $defaultPort in your firewall.'),
              SizedBox(height: 12),
              _HelpRow(Icons.wifi_tethering, 'Dropit discovery uses multicast $defaultMulticastGroup by default.'),
              SizedBox(height: 12),
              _HelpRow(Icons.devices, 'Disable Wi-Fi guest/client isolation if devices remain hidden.'),
              SizedBox(height: 16),
              Text('Local transfers use the Dropit Engine.'),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _HelpRow extends StatelessWidget {
  const _HelpRow(this.icon, this.message);
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}
