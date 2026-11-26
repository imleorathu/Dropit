import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:flutter/material.dart';

class DropitPrivacyPage extends StatelessWidget {
  const DropitPrivacyPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const DropitAppBar(title: Text('Privacy in Dropit')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropitHeading(title: 'Privacy in Dropit', description: 'Local, direct, encrypted file sharing.'),
              SizedBox(height: 28),
              DropitPanel(
                child: Text(
                  'Nearby sharing uses the Dropit Engine. Files travel directly between devices on your local network. No account is required for nearby sharing.\n\n'
                  'HTTPS encryption is enabled by default. Dropit verifies the receiver’s certificate before sending file details or content. Turning encryption off in Settings removes that protection.\n\n'
                  'Device discovery shares your chosen device name, model, address, and protocol identity with nearby peers. Choose a device name you are comfortable sharing.\n\n'
                  'Received files, transfer history, favorites, and preferences are stored on your device. You control the save location, history, automatic acceptance, and receiver PIN in Settings.\n\n'
                  'Browser sharing is an optional mode. Remote connections can use configured signaling and STUN servers. These modes have different network requirements from nearby sharing.\n\n'
                  'System file pickers, photo permissions, and share extensions are provided by your operating system. External links open in your browser.',
                  style: TextStyle(height: 1.7),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
