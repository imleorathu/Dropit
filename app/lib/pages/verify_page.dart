import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/provider/security_provider.dart';
import 'package:dropit_app/util/fingerprint_alphabet.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/mornye/app_glass_navigation.dart';
import 'package:dropit_app/widget/responsive_list_view.dart';
import 'package:flutter/material.dart';
import 'package:refena_flutter/refena_flutter.dart';

class CombinedFingerprint {
  final String combined;
  final List<IconData> icons;

  CombinedFingerprint({
    required this.combined,
    required this.icons,
  });

  factory CombinedFingerprint.load(BuildContext context, String fingerprint) {
    final myFingerprint = context.read(securityProvider.select((s) => s.certificateHash));
    final fingerprints = [myFingerprint, fingerprint]..sort();
    final combined = fingerprints.join();
    final icons = fingerprintToIcons(combined);
    return CombinedFingerprint(
      combined: combined,
      icons: icons,
    );
  }
}

enum VerifyMode {
  icons,
  text,
}

/// Verifies the identity of a discovered device by comparing the fingerprints
/// of both sides.
class VerifyPage extends StatefulWidget {
  final CombinedFingerprint fingerprint;

  const VerifyPage({required this.fingerprint});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  VerifyMode _mode = VerifyMode.icons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DropitAppBar(
        title: Text(t.verifyPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        children: [
          DropitPanel(
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: AppGlassSegmented(
                      options: [
                        AppGlassSegmentOption(label: t.verifyPage.icons),
                        AppGlassSegmentOption(label: t.verifyPage.text),
                      ],
                      value: _mode == VerifyMode.icons ? 0 : 1,
                      onChanged: (index) => setState(() => _mode = index == 0 ? VerifyMode.icons : VerifyMode.text),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                VerifyWidget(
                  mode: _mode,
                  fingerprint: widget.fingerprint,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    t.verifyPage.question,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VerifyWidget extends StatelessWidget {
  final VerifyMode mode;
  final CombinedFingerprint fingerprint;

  const VerifyWidget({
    required this.mode,
    required this.fingerprint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        switch (mode) {
          VerifyMode.icons => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final icon in fingerprint.icons) Icon(icon, size: 32),
                ],
              ),
            ),
          ),
          VerifyMode.text => SelectableText(fingerprint.combined),
        },
      ],
    );
  }
}
