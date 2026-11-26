import 'package:dropit_app/gen/strings.g.dart';
import 'package:dropit_app/pages/debug/debug_page.dart';
import 'package:dropit_app/widget/dropit/dropit_logo.dart';
import 'package:dropit_app/widget/dropit/dropit_ui.dart';
import 'package:dropit_app/widget/responsive_list_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:routerino/routerino.dart';
import 'package:url_launcher/url_launcher.dart';

final _translatorWithGithubRegex = RegExp(r'(.+) \(@([\w\-_]+)\)');

class AboutPage extends StatelessWidget {
  const AboutPage();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: DropitAppBar(
        title: Text(t.aboutPage.title),
      ),
      body: ResponsiveListView(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: [
          const SizedBox(height: 20),
          DropitPanel(
            child: Column(
              children: [
                const DropitLogo(withText: true),
                const SizedBox(height: 6),
                const Text(
                  'Dropit · Local file sharing',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Dropit is an independent app with its own interface and identity. Its discovery, encryption, and transfer engine is part of the Dropit Project, by Aanantharasa Rathursikan and contributors, under Apache License 2.0.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropitPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dropit Project · Original author', style: TextStyle(fontWeight: FontWeight.bold)),
                Text.rich(
                  _buildContributor(
                    label: 'Aanantharasa Rathursikan (@imleorathu)',
                    primaryColor: primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await launchUrl(Uri.parse('https://www.apache.org/licenses/LICENSE-2.0'));
                      },
                      child: const Text('Apache License 2.0'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await context.push(() => const LicensePage());
                      },
                      child: const Text('License Notices'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await context.push(() => const DebugPage());
                      },
                      child: const Text('Debugging'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

/// Displays the contributor name and links to their github profile.
InlineSpan _buildContributor({required String label, required Color primaryColor, bool newLine = false}) {
  final newLineStr = newLine ? '\n' : '';

  if (label.startsWith('@')) {
    // Only github name
    return TextSpan(
      text: '$newLineStr$label',
      style: TextStyle(color: primaryColor),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          await launchUrl(Uri.parse('https://github.com/${label.substring(1)}'), mode: LaunchMode.externalApplication);
        },
    );
  }

  final match = _translatorWithGithubRegex.firstMatch(label);
  if (match != null) {
    // Full name and github name
    final fullName = match.group(1)!;
    final githubName = match.group(2)!;
    return TextSpan(
      children: [
        TextSpan(text: '$newLineStr$fullName'),
        const TextSpan(text: ' '),
        TextSpan(
          text: '@$githubName',
          style: TextStyle(color: primaryColor),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(Uri.parse('https://github.com/$githubName'), mode: LaunchMode.externalApplication);
            },
        ),
      ],
    );
  }

  // Only full name
  return TextSpan(text: '$newLineStr$label');
}
