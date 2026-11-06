import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/ai_consent.dart';
import 'package:forditva/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiConsent.granted.value = null;
  });

  test('never asked is null, and the answer is stored', () async {
    await AiConsent.load();
    expect(AiConsent.granted.value, isNull);
    await AiConsent.set(true);
    AiConsent.granted.value = null;
    await AiConsent.load();
    expect(AiConsent.granted.value, isTrue);
    await AiConsent.set(false);
    await AiConsent.load();
    expect(AiConsent.granted.value, isFalse);
  });

  test('require throws when there is no dialog to ask with', () async {
    await AiConsent.set(false);
    await expectLater(AiConsent.require(), throwsA(isA<AiConsentDeclined>()));
  });

  test('require passes after consent', () async {
    await AiConsent.set(true);
    await AiConsent.require();
  });

  test('welcome start language', () {
    expect(welcomeStartLanguage(saved: null, device: 'hu'), 'hu');
    expect(welcomeStartLanguage(saved: null, device: 'en'), 'en');
    expect(welcomeStartLanguage(saved: null, device: 'fr'), 'de');
    expect(welcomeStartLanguage(saved: 'en', device: 'hu'), 'en');
    expect(welcomeStartLanguage(saved: 'xx', device: 'hu'), 'hu');
  });
}
