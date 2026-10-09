import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';

const Color _navGreen = Color(0xFF436F4D);

/// First-use tip above the History and Tutor history lists: "swipe left to
/// delete" (2026-10-09). Shown until the user closes it or deletes an entry
/// by swiping ([markUsed]); remembered per list under [prefKey].
class SwipeDeleteTip extends StatefulWidget {
  final String prefKey;

  const SwipeDeleteTip({super.key, required this.prefKey});

  /// Call after a swipe-delete: the user has found the gesture, so the tip
  /// is no longer needed.
  static Future<void> markUsed(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
    _dismissed.value = {..._dismissed.value, prefKey};
  }

  static final ValueNotifier<Set<String>> _dismissed = ValueNotifier({});

  @override
  State<SwipeDeleteTip> createState() => _SwipeDeleteTipState();
}

class _SwipeDeleteTipState extends State<SwipeDeleteTip> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    SwipeDeleteTip._dismissed.addListener(_onDismissed);
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final seen = prefs.getBool(widget.prefKey) ?? false;
      setState(() => _show = !seen);
    });
  }

  @override
  void dispose() {
    SwipeDeleteTip._dismissed.removeListener(_onDismissed);
    super.dispose();
  }

  void _onDismissed() {
    if (SwipeDeleteTip._dismissed.value.contains(widget.prefKey) && _show) {
      setState(() => _show = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _navGreen, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.swipe_left, color: _navGreen, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.swipeToDeleteTip,
                style: GoogleFonts.robotoCondensed(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black54),
              onPressed: () => SwipeDeleteTip.markUsed(widget.prefKey),
            ),
          ],
        ),
      ),
    );
  }
}
