import 'package:flutter/material.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';
import '../services/token_balance.dart';
import 'wallet_dialogs.dart';

const Color _navGreen = Color(0xFF436F4D);

/// Call before starting any AI request that spends WIUs (translate, image
/// processing, Tutor). Blocks with a friendly dialog and returns false if the
/// balance is empty; shows a lightweight low-balance warning (but still
/// proceeds) once it's running low. Returns true when the caller should go
/// ahead (Markus, 2026-07-10: block at 0, warn under 200).
Future<bool> ensureWiuBalance(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  // No wallet yet (or it needs the recovery code): set it up first.
  if (TokenBalance.instance.state.value != WalletState.ready) {
    final ready = await ensureWallet(context);
    if (!ready || !context.mounted) return false;
  }
  if (TokenBalance.instance.isEmpty) {
    await showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: _navGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.wiuEmptyTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _navGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.wiuEmptyBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        loc.ok,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    return false;
  }

  if (TokenBalance.instance.isLow) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.wiuLowBody)));
  }
  return true;
}
