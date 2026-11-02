import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/token_balance.dart';

const Color _navGreen = Color(0xFF436F4D);

/// Roboto Condensed for every text in [child], as on the rest of the app
/// (Markus, 2026-10-29: fewer bad line breaks in long German words).
Widget condensedDialog(BuildContext context, Widget child) {
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      textTheme: GoogleFonts.robotoCondensedTextTheme(theme.textTheme),
    ),
    child: child,
  );
}

/// The message for a failed wallet call.
String walletErrorText(AppLocalizations loc, WalletError kind) {
  switch (kind) {
    case WalletError.invalidCode:
      return loc.codeInvalid;
    case WalletError.codeLocked:
      return loc.codeLockedHour;
    case WalletError.rateLimited:
      return loc.codeRateLimited;
    case WalletError.needsRecovery:
      return loc.recoverNeededBody;
    case WalletError.recoveryLimit:
      return loc.recoverLimit;
    case WalletError.deviceLinked:
      return loc.recoverDeviceLinked;
    case WalletError.network:
      return loc.codeNetworkError;
    case WalletError.unavailable:
      return loc.codeUnavailable;
  }
}

/// Makes sure this install has a working wallet before an AI request:
/// a new install picks "start new" or "recovery code" first (Alex's client:
/// offer Recover BEFORE registering, since a phone with a wallet can't
/// recover another one). Returns true when the wallet is ready.
Future<bool> ensureWallet(BuildContext context) async {
  switch (TokenBalance.instance.state.value) {
    case WalletState.ready:
      return true;
    case WalletState.none:
      return showWalletWelcome(context);
    case WalletState.needsRecovery:
      return showRecoverDialog(context, needed: true);
  }
}

/// First launch: start with 200 WIU or bring a wallet back.
Future<bool> showWalletWelcome(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final recover = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => _WalletDialog(
          icon: Icons.account_balance_wallet_outlined,
          title: loc.walletWelcomeTitle,
          body: Text(
            loc.walletWelcomeBody,
            textAlign: TextAlign.center,
            style: _bodyStyle,
          ),
          actions: [
            _primaryButton(
              loc.walletStartNew,
              () => Navigator.of(dialogContext).pop(false),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                loc.walletHaveRecoveryCode,
                style: const TextStyle(fontSize: 17, color: _navGreen),
              ),
            ),
          ],
        ),
  );
  if (recover == null || !context.mounted) return false;
  if (recover) return showRecoverDialog(context);

  String? code;
  try {
    code = await _withLoader(context, TokenBalance.instance.createWallet);
  } on WalletException catch (e) {
    if (!context.mounted) return false;
    if (e.kind == WalletError.needsRecovery) {
      return showRecoverDialog(context, needed: true);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.kind == WalletError.network
              ? loc.walletNeedsInternet
              : walletErrorText(loc, e.kind),
        ),
      ),
    );
    return false;
  }
  if (code != null && context.mounted) {
    await showRecoveryCodeDialog(context, code);
  }
  return true;
}

/// Shows [code] once, with a copy button. Not dismissible by tapping outside,
/// so the user can't skip it by accident.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) {
  final loc = AppLocalizations.of(context)!;
  // Groups of 5 are easier to copy by hand; the server ignores spaces.
  final grouped = [
    for (var i = 0; i < code.length; i += 5)
      code.substring(i, (i + 5).clamp(0, code.length)),
  ].join(' ');
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (dialogContext) => _WalletDialog(
          icon: Icons.key_outlined,
          title: loc.recoveryCodeTitle,
          body: Column(
            children: [
              Text(
                loc.recoveryCodeBody,
                textAlign: TextAlign.center,
                style: _bodyStyle,
              ),
              const SizedBox(height: 16),
              SelectableText(
                grouped,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.copiedToClipboard)),
                  );
                },
                icon: const Icon(Icons.copy, color: _navGreen),
                label: Text(
                  loc.copyToClipboard,
                  style: const TextStyle(color: _navGreen),
                ),
              ),
            ],
          ),
          actions: [
            _primaryButton(
              loc.recoveryCodeDone,
              () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
  );
}

/// Asks for the recovery code and moves that wallet to this install.
/// [needed]: this phone already has a wallet (reinstall), so say why.
Future<bool> showRecoverDialog(
  BuildContext context, {
  bool needed = false,
}) async {
  final loc = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  String? error;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> submit() async {
              if (!TokenBalance.isRecoveryCodeFormat(controller.text)) {
                setState(() => error = loc.codeInvalid);
                return;
              }
              setState(() {
                busy = true;
                error = null;
              });
              try {
                await TokenBalance.instance.recover(controller.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on WalletException catch (e) {
                setState(() {
                  busy = false;
                  error = walletErrorText(loc, e.kind);
                });
              }
            }

            return _WalletDialog(
              icon: Icons.restore,
              title: loc.recoverTitle,
              body: Column(
                children: [
                  if (needed) ...[
                    Text(
                      loc.recoverNeededBody,
                      textAlign: TextAlign.center,
                      style: _bodyStyle,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: loc.recoverHint,
                      errorText: error,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => busy ? null : submit(),
                  ),
                ],
              ),
              actions: [
                busy
                    ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(color: _navGreen),
                    )
                    : _primaryButton(loc.recoverButton, submit),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      busy
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    loc.cancel,
                    style: const TextStyle(fontSize: 17, color: _navGreen),
                  ),
                ),
              ],
            );
          },
        ),
  );
  controller.dispose();
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.recoverDone)));
  }
  return ok == true;
}

/// Confirms, then rotates the recovery code and shows the new one.
Future<void> showNewRecoveryCodeFlow(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final go = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => condensedDialog(
          dialogContext,
          AlertDialog(
            content: Text(loc.newRecoveryCodeConfirm, style: _bodyStyle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  loc.cancel,
                  style: const TextStyle(fontSize: 17, color: _navGreen),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  loc.newRecoveryCodeCreate,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _navGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
  );
  if (go != true || !context.mounted) return;
  try {
    final code = await _withLoader(
      context,
      TokenBalance.instance.rotateRecoveryCode,
    );
    if (context.mounted) await showRecoveryCodeDialog(context, code);
  } on WalletException catch (e) {
    if (!context.mounted) return;
    if (e.kind == WalletError.needsRecovery) {
      await showRecoverDialog(context, needed: true);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(walletErrorText(loc, e.kind))));
  }
}

// A spinner over the page while a wallet call runs.
Future<T> _withLoader<T>(BuildContext context, Future<T> Function() run) async {
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator(color: _navGreen)),
        ),
  );
  try {
    return await run();
  } finally {
    navigator.pop();
  }
}

const TextStyle _bodyStyle = TextStyle(
  fontSize: 18,
  color: Colors.black87,
  height: 1.3,
);

Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: _navGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  ),
);

// Same look as the "WIU empty" dialog in wiu_gate.dart.
class _WalletDialog extends StatelessWidget {
  const _WalletDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return condensedDialog(context, _dialog());
  }

  Widget _dialog() {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _navGreen),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _navGreen,
              ),
            ),
            const SizedBox(height: 12),
            body,
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}
