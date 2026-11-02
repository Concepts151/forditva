// lib/profile_settings_page.dart
//
// "Profile and Settings" screen — App Settings, Credits and Language Learning.
// All user-facing text comes from the localization files (lib/l10n/*.arb) via
// AppLocalizations, so it switches with the app language and Markus can edit
// every string in one place.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'models/language_enum.dart';
import 'services/history_store.dart';
import 'services/level_pref.dart';
import 'services/third_language_pref.dart';
import 'services/token_balance.dart';
import 'widgets/wallet_dialogs.dart';

const Color _navGreen = Color(0xFF436F4D);
const Color _pageBg = Color(0xFFF6F3F7);
const Color _sectionBar = Color(0xFFD8D8D8);
const Color _labelDark = Color(0xFF222222);
const Color _fieldBorder = Color(0xFF9E9E9E);
const Color _progressEmpty = Color(0xFFBFD0BF);
const Color _navOrange = Color(0xFFCC8A2E);

const String _profileUrl = 'https://wir-in-ungarn.hu';

// Markus sent the section text/button labels on 2026-07-11 but left the
// actual link empty ("(Link: )"); real URL sent 2026-07-14.
const String _privacyPolicyUrl = 'https://wir-in-ungarn.hu/datenschutz-forditva/';

// Language names are shown as endonyms regardless of UI language.
const List<String> _languages = ['Deutsch', 'English', 'Magyar'];

class ProfileSettingsPage extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;

  const ProfileSettingsPage({super.key, required this.onLocaleChanged});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _saveHistory = HistoryStore.enabled;
  bool _howItWorksExpanded = true;
  int _level = LevelPref.level;
  final TextEditingController _codeController = TextEditingController();
  // The "How it works" box's always-visible scrollbar needs its own
  // controller; without one Flutter threw an error every time Settings opened.
  final ScrollController _howItWorksScroll = ScrollController();
  bool _isRedeeming = false;

  // The status bar shows 7 blocks: all filled while the balance is at or above
  // one full band (700 WIUs = 100 per block), then depleting proportionally
  // below that.
  static const int _statusTotal = 7;
  static const int _fullBand = 700;

  AppLocalizations get _loc => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    TokenBalance.instance.load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _howItWorksScroll.dispose();
    super.dispose();
  }

  int _filledBlocks(int balance) {
    if (balance >= _fullBand) return _statusTotal;
    return (balance / _fullBand * _statusTotal).round().clamp(0, _statusTotal);
  }

  // ─── handlers ──────────────────────────────────────────────────────
  void _onLanguageChanged(String? val) {
    if (val == null) return;
    final locale =
        val == 'Deutsch'
            ? const Locale('de')
            : val == 'Magyar'
            ? const Locale('hu')
            : const Locale('en');
    // No pop: the page rebuilds in the new language so the change is visible.
    widget.onLocaleChanged(locale);
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              _loc.clearEntireHistory,
              style: GoogleFonts.robotoCondensed(),
            ),
            content: Text(_loc.clearHistoryConfirm, style: GoogleFonts.roboto()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_loc.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _loc.delete,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok == true && mounted) {
      await HistoryStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loc.historyCleared)));
    }
  }

  Future<void> _submitCode() async {
    if (_isRedeeming) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loc.pleaseEnterCode)));
      return;
    }
    if (!TokenBalance.isGiftCodeFormat(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loc.codeInvalid)));
      return;
    }

    // A gift code needs a wallet (new install, or one that needs recovery).
    if (!await ensureWallet(context) || !mounted) return;

    setState(() => _isRedeeming = true);
    try {
      final value = await TokenBalance.instance.redeem(code);
      if (!mounted) return;
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value > 0
                ? _loc.creditsAdded(value)
                : _loc.codeAlreadyAdded,
          ),
        ),
      );
    } on WalletException catch (e) {
      if (!mounted) return;
      if (e.kind == WalletError.needsRecovery) {
        await showRecoverDialog(context, needed: true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(walletErrorText(_loc, e.kind))));
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  Future<void> _openProfile() async {
    final uri = Uri.parse(_profileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loc.couldNotOpenPage)));
    }
  }

  Future<void> _openPrivacyPolicy() async {
    if (_privacyPolicyUrl.isEmpty) {
      // Markus hasn't sent the real link yet — fail loud instead of
      // launching an empty/invalid URL.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy policy link not set yet')),
      );
      return;
    }
    final uri = Uri.parse(_privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loc.couldNotOpenPage)));
    }
  }

  // ─── build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _navGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _loc.profileAndSettings,
          style: GoogleFonts.robotoCondensed(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _sectionHeader(_loc.appSettings),
          _padded(_appLanguage()),
          _padded(_thirdLanguageSelector()),
          _padded(_saveHistoryRow()),
          _padded(_clearHistoryRow()),

          _sectionHeader(_loc.credits),
          _padded(_howItWorksCard()),
          _padded(_currentStatus()),
          _padded(_codeForFilling()),
          _padded(_recoveryCode()),
          _padded(_organizeCredits()),

          _sectionHeader(_loc.languageLearning),
          _padded(_languageLearning()),

          _sectionHeader(_loc.legalPrivacyTitle),
          _padded(_legalPrivacy()),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ─── reusable bits ─────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Container(
    width: double.infinity,
    color: _sectionBar,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Text(
      title,
      style: GoogleFonts.robotoCondensed(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _navGreen,
      ),
    ),
  );

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    child: child,
  );

  TextStyle get _label => GoogleFonts.robotoCondensed(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: _labelDark,
  );

  TextStyle get _greenBody => GoogleFonts.robotoCondensed(
    fontSize: 16,
    height: 1.35,
    color: _navGreen,
  );

  // ─── App Settings ──────────────────────────────────────────────────
  Widget _appLanguage() {
    final code = Localizations.localeOf(context).languageCode;
    final currentName =
        code == 'de'
            ? 'Deutsch'
            : code == 'hu'
            ? 'Magyar'
            : 'English';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_loc.appLanguage, style: _label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currentName,
          icon: const Icon(Icons.keyboard_arrow_down),
          style: GoogleFonts.robotoCondensed(fontSize: 20, color: _labelDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _fieldBorder),
            ),
          ),
          items:
              _languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
          onChanged: _onLanguageChanged,
        ),
      ],
    );
  }

  // Lets the user swap English out for one other language (besides the
  // fixed Hungarian/German pair) as the flexible third translation option
  // across Conversation, Document and Image.
  Widget _thirdLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_loc.thirdLanguage, style: _label),
        const SizedBox(height: 10),
        ValueListenableBuilder<Language>(
          valueListenable: ThirdLanguagePref.notifier,
          builder: (context, selected, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  thirdLanguageOptions.map((lang) {
                    final isSelected = lang == selected;
                    return GestureDetector(
                      onTap: () => ThirdLanguagePref.set(lang),
                      child: Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? _navGreen : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            // Markus's bordered square flag (dark border shows on
                            // the light settings background); never round.
                            'assets/flags/${lang.label}_B.png',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  color: _progressEmpty,
                                  alignment: Alignment.center,
                                  child: Text(
                                    lang.label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _saveHistoryRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(_loc.saveHistory, style: _label),
      Switch(
        value: _saveHistory,
        activeThumbColor: Colors.white,
        activeTrackColor: _navGreen,
        onChanged: (v) {
          setState(() => _saveHistory = v);
          HistoryStore.setEnabled(v);
        },
      ),
    ],
  );

  Widget _clearHistoryRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(_loc.clearEntireHistory, style: _label),
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.black, size: 30),
        onPressed: _clearHistory,
      ),
    ],
  );

  // ─── Credits ───────────────────────────────────────────────────────
  Widget _howItWorksCard() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.black, width: 2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      children: [
        GestureDetector(
          onTap:
              () =>
                  setState(() => _howItWorksExpanded = !_howItWorksExpanded),
          child: Container(
            color: _navGreen,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _loc.howItWorks,
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _howItWorksExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        if (_howItWorksExpanded)
          Container(
            color: Colors.white,
            height: 150,
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Scrollbar(
              controller: _howItWorksScroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _howItWorksScroll,
                padding: const EdgeInsets.only(right: 8),
                child: Text(_loc.howItWorksBody, style: _greenBody),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _currentStatus() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_loc.currentStatus, style: _label),
      const SizedBox(height: 10),
      ValueListenableBuilder<int>(
        valueListenable: TokenBalance.instance.value,
        builder: (context, balance, _) {
          final filled = _filledBlocks(balance);
          // Low balance needs to read as a warning, not just "empty" (Markus,
          // 2026-07-10): 0-1 blocks filled is red, 2 is orange, 3+ stays the
          // normal green.
          final filledColor =
              filled <= 1
                  ? Colors.red
                  : filled == 2
                  ? _navOrange
                  : _navGreen;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(_statusTotal, (i) {
                  return Expanded(
                    child: Container(
                      height: 24,
                      margin: EdgeInsets.only(
                        right: i == _statusTotal - 1 ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: i < filled ? filledColor : _progressEmpty,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  );
                }),
              ),
              // Below the full band, show the exact count too, not just the
              // color (Markus, 2026-07-11: know internally/visibly how many
              // WIUs remain once it's under 700).
              if (balance < _fullBand) ...[
                const SizedBox(height: 6),
                Text(
                  _loc.wiuRemaining(balance),
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: filledColor,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ],
  );

  Widget _codeForFilling() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_loc.codeForFillingCredits, style: _label),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: _loc.topUpCodeHint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _fieldBorder),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isRedeeming ? null : _submitCode,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _navGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isRedeeming
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    ],
  );

  // Restore a wallet from another install, or replace a lost recovery code.
  Widget _recoveryCode() => ValueListenableBuilder<WalletState>(
    valueListenable: TokenBalance.instance.state,
    builder:
        (context, state, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _walletTextButton(
              _loc.recoverTitle,
              () => showRecoverDialog(
                context,
                needed: state == WalletState.needsRecovery,
              ),
            ),
            if (state == WalletState.ready)
              _walletTextButton(
                _loc.newRecoveryCode,
                () => showNewRecoveryCodeFlow(context),
              ),
          ],
        ),
  );

  Widget _walletTextButton(String label, VoidCallback onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(padding: EdgeInsets.zero),
    child: Text(
      label,
      style: GoogleFonts.robotoCondensed(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _navGreen,
        decoration: TextDecoration.underline,
      ),
    ),
  );

  Widget _organizeCredits() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_loc.organizeCredits, style: _label),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _openProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _loc.gotoProfile,
            style: GoogleFonts.robotoCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _legalPrivacy() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_loc.legalPrivacyBody, style: _greenBody),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _openPrivacyPolicy,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _loc.openPrivacyPolicy,
            style: GoogleFonts.robotoCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );

  // ─── Language Learning ─────────────────────────────────────────────
  Widget _languageLearning() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_loc.levelDescription, style: _greenBody),
      const SizedBox(height: 10),
      Text(_loc.levelTip, style: _greenBody),
      const SizedBox(height: 20),
      Text(_loc.myCurrentLevel, style: _label),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepButton(Icons.remove, () {
            setState(() => _level = (_level - 1).clamp(1, 99));
            LevelPref.set(_level);
          }),
          Container(
            width: 84,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _fieldBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _level.toString().padLeft(2, '0'),
              style: GoogleFonts.robotoCondensed(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: _labelDark,
              ),
            ),
          ),
          _stepButton(Icons.add, () {
            setState(() => _level = (_level + 1).clamp(1, 99));
            LevelPref.set(_level);
          }),
        ],
      ),
    ],
  );

  Widget _stepButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 56,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E2E2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: _labelDark, size: 26),
    ),
  );
}
