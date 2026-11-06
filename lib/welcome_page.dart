import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'services/ai_consent.dart';
import 'widgets/markup_text.dart';

const _navGreen = Color(0xFF436F4D);

/// The language to offer first (Markus, 2026-11-04): the one saved before,
/// else the phone's language if it is German, English or Hungarian, else
/// German.
String welcomeStartLanguage({String? saved, required String device}) {
  const supported = ['de', 'en', 'hu'];
  if (saved != null && supported.contains(saved)) return saved;
  if (supported.contains(device)) return device;
  return 'de';
}

/// Shown once before first use. "Agree" turns AI use on; "Not now" opens
/// the app with the AI features locked (each one asks again when tapped).
class WelcomePage extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  final VoidCallback onDone;
  const WelcomePage({
    super.key,
    required this.onLocaleChanged,
    required this.onDone,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _pickStartLanguage();
  }

  Future<void> _pickStartLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final device =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = welcomeStartLanguage(
      saved: prefs.getString('app_locale'),
      device: device,
    );
    if (!mounted) return;
    if (Localizations.localeOf(context).languageCode != code) {
      widget.onLocaleChanged(Locale(code));
    }
  }

  Future<void> _answer(bool agreed) async {
    await AiConsent.set(agreed);
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final current = Localizations.localeOf(context).languageCode;
    const body = TextStyle(fontSize: 16, height: 1.4, color: Colors.black);
    const heading = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    Widget para(String t, [TextStyle s = body]) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text.rich(markupSpan(t), style: s),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'de', label: Text('Deutsch')),
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'hu', label: Text('Magyar')),
                ],
                selected: {current},
                onSelectionChanged:
                    (s) => widget.onLocaleChanged(Locale(s.first)),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _navGreen,
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    para(
                      loc.welcomeTitle,
                      const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _navGreen,
                      ),
                    ),
                    para(loc.welcomeTagline, heading),
                    para(loc.welcomeIntro),
                    para(loc.welcomeDataHeading, heading),
                    para(loc.welcomeDataAi),
                    para(loc.welcomeNoAccount),
                    para(loc.welcomeDeviceId),
                    para(loc.welcomeContentNote),
                    para(loc.welcomeChoiceHeading, heading),
                    para(loc.welcomeChoiceBody),
                    para(loc.welcomeMore),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _navGreen),
                      onPressed: () => _answer(true),
                      child: Text(
                        loc.welcomeAgree,
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () => _answer(false),
                      child: Text(
                        loc.welcomeNotNow,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
