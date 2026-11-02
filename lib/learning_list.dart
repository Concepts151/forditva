import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forditva/tutor/tutor_page.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'services/learning_store.dart';
import 'spacing.dart';
import 'utils/utils.dart';
import 'package:forditva/widgets/swipe_delete_tip.dart';

/// Remembers that the "swipe left to delete" tip was seen on this list.
const _swipeTipKey = 'swipe_tip_tutor_history';

const Color _navGreen = Color(0xFF436F4D);

/// History of the Tutor (light-bulb) queries. Each entry is a Hungarian
/// sentence the user asked about; tapping it re-opens the saved explanation.
/// Searchable and per-item deletable (per Markus's spec).
class LearningListPage extends StatefulWidget {
  const LearningListPage({super.key});

  @override
  State<LearningListPage> createState() => _LearningListPageState();
}

class _LearningListPageState extends State<LearningListPage> {
  late Future<List<LearningEntry>> _entriesFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _entriesFuture = LearningStore.getAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(String id) async {
    SwipeDeleteTip.markUsed(_swipeTipKey);
    await LearningStore.delete(id);
    setState(_load);
  }

  /// Pulls the human-readable translation out of the stored explanation JSON,
  /// used as the short "intro" line under each sentence.
  String _introFor(LearningEntry e) {
    final tutor = parseTutorEntry(e.explanation);
    if (tutor != null) return tutorEntryPreview(tutor);
    try {
      final parsed = jsonDecode(stripCodeFence(e.explanation));
      if (parsed is Map && parsed['translation'] is String) {
        return (parsed['translation'] as String).trim();
      }
    } catch (_) {}
    return '';
  }

  void _openEntry(LearningEntry e) {
    // Entries saved by the new Tutor page (2026-10-09) reopen there with
    // their saved results, so revisiting costs nothing.
    final tutor = parseTutorEntry(e.explanation);
    if (tutor != null) {
      final results = tutor['results'];
      TutorLauncher.open(
        e.sentence,
        cached: results is Map<String, dynamic> ? results : null,
        cachedLang: tutor['lang'] as String?,
      );
      return;
    }
    Map<String, dynamic> parsed = {};
    try {
      final decoded = jsonDecode(stripCodeFence(e.explanation));
      if (decoded is Map<String, dynamic>) parsed = decoded;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(width: 0.5, color: Colors.black),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.sentence,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _navGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Image.asset(
                          'assets/png24/black/b_close.png',
                          width: 24,
                          height: 24,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                        parsed.isEmpty
                            ? Text(e.explanation)
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _section(
                                  AppLocalizations.of(
                                    context,
                                  )!.grammarExplanation,
                                  parsed['grammar_explanation'],
                                ),
                                _section(
                                  AppLocalizations.of(context)!.keyVocabulary,
                                  parsed['key_vocabulary'],
                                ),
                                _section(
                                  AppLocalizations.of(
                                    context,
                                  )!.translationHeading,
                                  parsed['translation'],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _section(String title, dynamic content) {
    if (content == null || (content is String && content.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content.toString(),
            style: GoogleFonts.robotoCondensed(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg-dark.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged:
                  (value) => setState(
                    () => _searchQuery = value.trim().toLowerCase(),
                  ),
              decoration: InputDecoration(
                hintText: loc.searchHistory,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SwipeDeleteTip(prefKey: _swipeTipKey),
          Expanded(
            child: FutureBuilder<List<LearningEntry>>(
              future: _entriesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? [];
                final filtered =
                    all.where((e) {
                      if (_searchQuery.isEmpty) return true;
                      return e.sentence.toLowerCase().contains(_searchQuery) ||
                          _introFor(e).toLowerCase().contains(_searchQuery);
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      loc.noHistoryFound,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  // Bottom was 100, stacking on the nav-bar white area into
                  // ~133px of dead space (spacing audit, 2026-07-13).
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, Spacing.sm),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final entry = filtered[i];
                    final intro = _introFor(entry);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Slidable(
                        key: ValueKey(entry.id),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          dismissible: DismissiblePane(
                            onDismissed: () => _delete(entry.id),
                          ),
                          children: [
                            SlidableAction(
                              onPressed: (_) => _delete(entry.id),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: loc.delete,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _openEntry(entry),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            // Bulb sits in the top-right corner like on
                            // History/Favorites; only the sentence stops
                            // short of it (Markus, 2026-10-09).
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        right: 40,
                                      ),
                                      child: Text(
                                        entry.sentence,
                                        style: GoogleFonts.robotoCondensed(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: _navGreen,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (intro.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        intro,
                                        style: GoogleFonts.robotoCondensed(
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Image.asset(
                                    'assets/png24/black/b_lightbulb.png',
                                    width: 28,
                                    height: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
