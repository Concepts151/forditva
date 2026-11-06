import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:forditva/services/ai_consent.dart';
import 'package:forditva/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiConsent.granted.value = null;
  });

  Future<void> pump(WidgetTester t, {required void Function() onDone}) async {
    final locale = ValueNotifier<Locale>(const Locale('de'));
    await t.binding.setSurfaceSize(const Size(400, 900));
    await t.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder:
            (_, l, __) => MaterialApp(
              locale: l,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: WelcomePage(
                onLocaleChanged: (v) => locale.value = v,
                onDone: onDone,
              ),
            ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('language switch changes the text, Agree stores consent', (
    t,
  ) async {
    var done = false;
    await pump(t, onDone: () => done = true);
    // The test device speaks English, so English is offered first.
    expect(find.text('Agree and get started'), findsOneWidget);
    await t.tap(find.text('Deutsch'));
    await t.pumpAndSettle();
    expect(find.text('Zustimmen und starten'), findsOneWidget);
    await t.tap(find.text('Magyar'));
    await t.pumpAndSettle();
    expect(find.text('Hozzájárulok és elkezdem'), findsOneWidget);
    await t.tap(find.text('Hozzájárulok és elkezdem'));
    await t.pumpAndSettle();
    expect(AiConsent.granted.value, isTrue);
    expect(done, isTrue);
  });

  testWidgets('Not now stores false and still continues', (t) async {
    var done = false;
    await pump(t, onDone: () => done = true);
    await t.tap(find.text('Not now'));
    await t.pumpAndSettle();
    expect(AiConsent.granted.value, isFalse);
    expect(done, isTrue);
  });
}
