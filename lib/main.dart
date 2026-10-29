import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:forditva/document/document_language_state.dart';
import 'package:forditva/document/translationstate.dart';
import 'package:forditva/widgets/splash_screen.dart'; // Adjust path!
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document/document_translation_page.dart';
import 'favorite.dart';
import 'firebase_options.dart';
import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'history.dart';
import 'image_page.dart';
import 'learning_list.dart';
import 'profile_settings_page.dart';
import 'services/history_store.dart';
import 'services/level_pref.dart';
import 'services/third_language_pref.dart';
import 'services/token_balance.dart';
import 'spacing.dart';
import 'textpage.dart';
import 'tutor/tutor_page.dart';
import 'widgets/wallet_dialogs.dart';

// Colors and constants
const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);
const Color textGrey = Color(0xFF898888);
const Color gold = Colors.amber;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load();
  await _initFirebaseAppCheck();
  await ThirdLanguagePref.load();
  await LevelPref.load();
  await HistoryStore.load();
  await TokenBalance.instance.load();
  // Not awaited: a sync can take up to 20 s on a bad connection. The
  // balance is a ValueNotifier, so the UI picks up the result when it lands.
  unawaited(TokenBalance.instance.start());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranslationState()),
        ChangeNotifierProvider(create: (_) => DocumentLanguageState()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Activates Firebase App Check (Play Integrity on Android, App Attest on
/// iOS) so the document-conversion endpoint can verify requests come from a
/// genuine, unmodified install of this app, with no bundled secret to
/// extract (Markus, 2026-08: "properly secure solution", not a static API
/// key). Non-fatal: if Firebase can't start (iOS is still a placeholder in
/// firebase_options.dart), this logs and the app starts normally.
///
/// Play Integrity only passes for apps installed from Google Play, so
/// debug builds use the debug provider: the first run prints a debug token
/// in logcat, which must be registered in the Firebase console (App Check >
/// Apps > Manage debug tokens) before that phone gets valid tokens.
Future<void> _initFirebaseAppCheck() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid:
          kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestProvider(),
    );
  } catch (e) {
    debugPrint(
      'Firebase App Check not active (expected on iOS until its '
      'Firebase app is configured): $e',
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ValueNotifier<Locale?> _localeNotifier = ValueNotifier<Locale?>(null);
  static const _localePrefKey = 'app_locale';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLocale();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // API.md §5: sync the wallet when the app comes to the foreground, if the
  // last sync is 8 hours old or more (the client checks the interval).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(TokenBalance.instance.syncIfDue());
    }
  }

  // Restore the language the user last picked in Settings, so it (and the
  // preset translation pair derived from it) survives an app restart.
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefKey);
    if (code != null && code.isNotEmpty) {
      _localeNotifier.value = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    _localeNotifier.value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefKey, locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: _localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          // <-- INSIDE THIS WIDGET
          locale: locale,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          title: 'Forditva',
          theme: ThemeData(primarySwatch: Colors.green),

          // ✅ ADD THESE LINES
          initialRoute: '/',
          routes: {
            '/':
                (context) =>
                    SplashScreenWithLocaleSetter(onLocaleChanged: setLocale),
            '/home': (context) => MainScreen(onLocaleChanged: setLocale),
          },
        );
      },
    );
  }
}
// In the same file or a new one, but after SplashScreen is defined

class SplashScreenWithLocaleSetter extends StatelessWidget {
  final void Function(Locale) onLocaleChanged;
  const SplashScreenWithLocaleSetter({
    super.key,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SplashScreenRedirect(onLocaleChanged: onLocaleChanged);
  }
}

class SplashScreenRedirect extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  const SplashScreenRedirect({super.key, required this.onLocaleChanged});

  @override
  State<SplashScreenRedirect> createState() => _SplashScreenRedirectState();
}

class _SplashScreenRedirectState extends State<SplashScreenRedirect> {
  // Startup work is done before runApp, so this is only how long the logos
  // stay visible.
  static const _minSplashDuration = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(onLocaleChanged: widget.onLocaleChanged),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // The actual splash visuals
    return const SplashScreen();
  }
}

class MainScreen extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;

  const MainScreen({super.key, required this.onLocaleChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentPage = 1;

  // Anything that opens the Tutor (bulb, History, Favorites, Tutor history)
  // sets TutorLauncher.request; switch to the Tutor page when it does.
  @override
  void initState() {
    super.initState();
    TutorLauncher.request.addListener(_showTutorPage);
    // A new install picks "start with 200 WIU" or "recovery code" once the
    // home page is up; the WIU gate asks again if it was skipped.
    if (TokenBalance.instance.state.value == WalletState.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showWalletWelcome(context);
      });
    }
  }

  @override
  void dispose() {
    TutorLauncher.request.removeListener(_showTutorPage);
    super.dispose();
  }

  void _showTutorPage() {
    if (TutorLauncher.request.value != null && mounted) {
      setState(() => _currentPage = 7);
    }
  }

  // Lets the nav bar's bulb button reach into each page's state to open the
  // Tutor modal for whatever Hungarian text is currently on screen there.
  // The bulb sits at the same nav-bar position on all three pages now.
  final GlobalKey<State<TextPage>> _textPageKey = GlobalKey<State<TextPage>>();
  final GlobalKey<State<DocumentPlaceholderPage>> _documentPageKey =
      GlobalKey<State<DocumentPlaceholderPage>>();
  final GlobalKey<State<ImagePlaceholderPage>> _imagePageKey =
      GlobalKey<State<ImagePlaceholderPage>>();

  late final List<Widget> _pages = [
    SizedBox.shrink(), // 0: drawer/menu placeholder
    TextPage(
      key: _textPageKey,
      onOpenDocument: () => setState(() => _currentPage = 5),
    ), // 1: Conversation
    LearningListPage(), // 2: Learning List
    FavoritePage(),
    HistoryPage(), // 4: History (was placeholder)
    DocumentPlaceholderPage(key: _documentPageKey), // 5: Document
    ImagePlaceholderPage(key: _imagePageKey), // 6: Image
    const TutorPage(), // 7: Tutor (Markus, 2026-10-09)
  ];

  dynamic get _activePageState {
    switch (_currentPage) {
      case 1:
        return _textPageKey.currentState;
      case 5:
        return _documentPageKey.currentState;
      case 6:
        return _imagePageKey.currentState;
      default:
        return null;
    }
  }

  void _openTutor() {
    (_activePageState as dynamic)?.openTutor();
  }

  // Enabled only while there's actually Hungarian text to explain on the
  // currently active page.
  static final ValueNotifier<bool> _disabled = ValueNotifier(false);

  ValueListenable<bool> get _bulbEnabledListenable {
    final state = _activePageState;
    if (state != null) return state.hasHungarianText as ValueListenable<bool>;
    // Only the current page is mounted, and it is created in this same build
    // (app start or a page switch), so its GlobalKey has no State yet. Rebuild
    // after the frame so the bulb binds to that page's notifier; otherwise it
    // stayed grey on a freshly opened Document/Image page with Hungarian text.
    if (_currentPage == 1 || _currentPage == 5 || _currentPage == 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return _disabled;
  }

  String _getPageName(int idx) {
    switch (idx) {
      case 1:
        return AppLocalizations.of(context)!.conversation;
      case 2:
        return AppLocalizations.of(context)!.learningList;
      case 3:
        return AppLocalizations.of(context)!.favorites;
      case 4:
        return AppLocalizations.of(context)!.history;
      case 5:
        return AppLocalizations.of(context)!.documentMode;
      case 6:
        return AppLocalizations.of(context)!.imageMode;
      case 7:
        return 'Tutor';
      default:
        return '';
    }
  }

  // Every nav-bar page name in every supported language, so the font-size
  // calculation below always accounts for the longest one regardless of
  // which page/language is currently showing.
  static const List<String> _allPageNames = [
    'Conversation',
    'Text',
    'File',
    'Learning List',
    'Favorites',
    'History',
    'Gespräch',
    'Dokument',
    'Datei',
    'Lernliste',
    'Favoriten',
    'Verlauf',
    'Beszélgetés',
    'Dokumentum',
    'Fájl',
    'Tanulási lista',
    'Kedvencek',
    'Előzmények',
    'Tutor',
  ];

  /// One size for every nav-bar label (Markus, 2026-07-11: all labels the
  /// same size), now as large as the longest single WORD allows (Markus,
  /// 2026-10-09: maximum size for "Conversation" / "Beszélgetés"). Two-word
  /// labels ("Tanulási lista") wrap onto two lines at that size, so the
  /// size is also capped to fit two lines in [maxHeight].
  double _navLabelFontSize(double maxWidth, double maxHeight) {
    final maxForTwoLines = (maxHeight / (2 * _navLabelLineHeight)).floor();
    for (var size = 34; size >= 12; size--) {
      if (size > maxForTwoLines) continue;
      final style = GoogleFonts.robotoCondensed(
        fontWeight: FontWeight.w500,
        fontSize: size.toDouble(),
      );
      final fitsAll = _allPageNames.expand((n) => n.split(' ')).every((word) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        return painter.width <= maxWidth;
      });
      if (fitsAll) return size.toDouble();
    }
    return 12;
  }

  static const _navLabelLineHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    const double navBarHeight = 56.0;
    final double iconSize = navBarHeight * 0.5; // 60% of nav-bar height
    return Scaffold(
      appBar: null,
      // Markus, 2026-07-12: the white area behind the nav-bar pill should
      // stay white, just be taller (see bottomNavigationBar's top padding).
      backgroundColor: Colors.white,
      // A flat 16px top clearance (with the real inset stripped via
      // MediaQuery.removePadding) was only ever tuned against Android's
      // shorter status bar. iOS notches/Dynamic Island need 44-59pt, so the
      // card was starting almost under the status bar there (Markus,
      // 2026-07-13: "touching the network bar on top"). Use the device's
      // real safe-area inset instead of a hardcoded guess. The real inset
      // alone already clears the status bar; the +30 buffer added on top of
      // it (2026-07-13) was excess, producing a visibly oversized top gap
      // on every page (Markus, 2026-07-14). Down to Spacing.sm.
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          Spacing.sm + MediaQuery.of(context).viewPadding.top,
          0,
          0,
        ),
        child: _pages[_currentPage],
      ),

      bottomNavigationBar: Padding(
        // Lift the bar above the Android system navigation/gesture bar. Top
        // padding gives breathing room above the pill: 33 -> 16 -> 8, still
        // read as too much at 16 combined with each page's own gap above
        // the switcher (Markus, 2026-07-14, after testing +39). This is a
        // GLOBAL gap, so page-local bottom padding must not stack on top of
        // it — see image_page.dart, which had its own removed for exactly
        // that reason. Bottom padding is xs, since the system inset alone
        // already clears the home indicator.
        padding: EdgeInsets.fromLTRB(
          16,
          Spacing.sm,
          16,
          Spacing.sm + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Container(
          // The outline is painted ON TOP of the clipped coloured sections
          // (foregroundDecoration). Drawn underneath, the sections' anti-
          // aliased edges covered it and it looked uneven, worst at the
          // rounded ends (Markus, 2026-10-09, fixed version in Photoshop:
          // even outline plus a soft shadow).
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SizedBox(
            height: navBarHeight,
            child: Row(
              children: [
                // menu
                Flexible(
                  flex: 1,
                  child: Builder(
                    builder:
                        (ctx) => GestureDetector(
                          onTap:
                              () => Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => ProfileSettingsPage(
                                        onLocaleChanged: widget.onLocaleChanged,
                                      ),
                                ),
                              ),
                          child: Container(
                            color: navRed,
                            alignment: Alignment.center,
                            // Nudge the icon off the rounded left corner —
                            // it was sitting flush against the curve.
                            padding: const EdgeInsets.only(left: 8),
                            child: Image.asset(
                              'assets/png24/white/w_menu.png',
                              width: iconSize,
                              height: iconSize,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                        ),
                  ),
                ),

                // Tutor bulb: same nav-bar position on all three pages now,
                // always opens the Tutor for whatever Hungarian text is on
                // the currently active page. Page switching between
                // Conversation/Document/Image happens via the title area
                // (below) and the card's own document-mode icon.
                Flexible(
                  flex: 1,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _bulbEnabledListenable,
                    builder: (context, enabled, _) {
                      return GestureDetector(
                        onTap: !enabled ? null : _openTutor,
                        child: Container(
                          color: navRed,
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: enabled ? 1.0 : 0.4,
                            child: Image.asset(
                              'assets/png24/white/w_lightbulb.png',
                              width: iconSize,
                              height: iconSize,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // page title
                Flexible(
                  flex: 3,
                  child: GestureDetector(
                    onTap:
                        () => setState(() {
                          if (_currentPage == 1) {
                            _currentPage = 5;
                          } else if (_currentPage == 5) {
                            _currentPage = 6;
                          } else {
                            _currentPage = 1;
                          }
                        }),
                    child: Container(
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        // Was a per-label FittedBox, so short labels ("Bild")
                        // rendered larger than long ones ("Tanulási lista")
                        // (Markus, 2026-07-11: "never allowed to change it...
                        // all words there have always the same font size").
                        // Compute ONE size that fits the longest label across
                        // every language, and use it everywhere.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Text(
                              _getPageName(_currentPage),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.robotoCondensed(
                                fontWeight: FontWeight.w500,
                                fontSize: _navLabelFontSize(
                                  constraints.maxWidth,
                                  navBarHeight - 6,
                                ),
                                height: _navLabelLineHeight,
                                color: Colors.black,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // learning / favorite / history
                Flexible(
                  flex: 3,
                  child: Container(
                    color: navGreen,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _currentPage = 2),
                          child: Image.asset(
                            'assets/png24/white/w_learninglist.png',
                            width: iconSize,
                            height: iconSize,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _currentPage = 3),
                          child: Image.asset(
                            'assets/png24/white/w_favorit.png',
                            width: iconSize,
                            height: iconSize,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _currentPage = 4),
                          child: Image.asset(
                            'assets/png24/white/w_history.png',
                            width: iconSize,
                            height: iconSize,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
