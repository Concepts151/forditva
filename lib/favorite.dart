import 'package:flutter/material.dart';
import 'package:forditva/db/database.dart'; // adjust path if needed
import 'package:google_fonts/google_fonts.dart';

import 'flutter_gen/gen_l10n/app_localizations.dart';
import 'spacing.dart';
import 'widgets/tutor_dialog.dart';

const Color navGreen = Color(0xFF436F4D);

/// The Hungarian side of an entry, used by the Tutor button.
String _hungarianOf(Translation e) {
  if (e.fromLang.toUpperCase() == 'HU') return e.input;
  if (e.toLang.toUpperCase() == 'HU') return e.output;
  return e.input;
}

/// The Tutor bulb only makes sense when the entry actually has Hungarian text.
bool _hasHungarian(Translation e) =>
    e.fromLang.toUpperCase() == 'HU' || e.toLang.toUpperCase() == 'HU';
const Color gold = Colors.amber;

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  late final AppDatabase _db;
  late Future<List<Translation>> _favoritesFuture;
  late TextEditingController _searchController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _db = AppDatabase.instance;
    _searchController = TextEditingController();
    _loadFavorites();
  }

  void _loadFavorites() {
    _favoritesFuture = _db.translationDao.getAll().then(
      (all) => all.where((e) => e.isFavorite).toList(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: loc.searchFavorites, // ← localized hint
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Translation>>(
              future: _favoritesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allFavorites = snap.data ?? [];
                final filtered =
                    allFavorites.where((entry) {
                      final input = entry.input.toLowerCase();
                      final output = entry.output.toLowerCase();
                      return _searchQuery.isEmpty ||
                          input.contains(_searchQuery) ||
                          output.contains(_searchQuery);
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      loc.noFavoritesFound, // ← localized message
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      // Bulb + star sit in the top-right corner; only the
                      // source text stops short of them, the translation
                      // runs full width underneath (Markus, 2026-10-09).
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Texts
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: _hasHungarian(entry) ? 80 : 40,
                                ),
                                child: Text(
                                  entry.input,
                                  style: GoogleFonts.robotoCondensed(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: navGreen,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.output,
                                style: GoogleFonts.robotoCondensed(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),

                          Positioned(
                            top: -8,
                            right: -8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tutor (light-bulb): only when the entry has Hungarian.
                                if (_hasHungarian(entry))
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: Image.asset(
                                      'assets/images/bulb.png',
                                      width: 24,
                                      height: 24,
                                    ),
                                    tooltip: 'Tutor',
                                    onPressed:
                                        () => showTutorExplanation(
                                          context: context,
                                          hungarianText: _hungarianOf(entry),
                                          otherLangCode:
                                              entry.fromLang.toUpperCase() == 'HU'
                                                  ? entry.toLang
                                                  : entry.fromLang,
                                        ),
                                  ),

                                // Unfavorite star
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.star,
                                    color: gold,
                                    size: 24,
                                  ),
                                  onPressed: () async {
                                    await _db.translationDao.toggleFavorite(
                                      entry.id,
                                      false,
                                    );
                                    if (!mounted) return;
                                    setState(_loadFavorites);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.removedFromFavorites,
                                        ), // ← localized
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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
