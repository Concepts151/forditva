import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';

const Color _navRed = Color(0xFFCD2A3E);
const Color _navGreen = Color(0xFF436F4D);

/// Visual page picker for a PDF. Renders each page to a thumbnail and lets the
/// user tick the pages to import, instead of typing page numbers (Markus,
/// 2026-07-16). Shown as a modal over the Image page, which stays dimmed
/// behind it. Returns the sorted 1-based page numbers, or null if cancelled.
class PdfPageSelectorDialog extends StatefulWidget {
  const PdfPageSelectorDialog({
    super.key,
    required this.file,
    this.initialSelection = const {},
    this.convertedFrom,
  });

  final File file;

  /// The original file type ("DOCX", "XLSX", ...) when [file] is the PDF
  /// the conversion server made from it. The picker then says so, instead
  /// of "pdf-importer" for a Word file (Markus, 2026-10-29: "the normal
  /// user will not understand").
  final String? convertedFrom;

  /// Pages ticked when the picker opens: the pages translated last time,
  /// when the user comes back to the same PDF to pick others (Markus,
  /// 2026-10-25). The picker opens on the first of them.
  final Set<int> initialSelection;

  @override
  State<PdfPageSelectorDialog> createState() => _PdfPageSelectorDialogState();
}

class _PdfPageSelectorDialogState extends State<PdfPageSelectorDialog> {
  PdfDocument? _doc;
  int _pageCount = 0;
  int _current = 1; // 1-based
  final Set<int> _selected = {};
  final Map<int, Uint8List> _thumbs = {};
  bool _failed = false;

  // Android cannot render two pages in parallel, so every render is chained
  // onto the previous one instead of fired concurrently.
  Future<void> _renderChain = Future.value();

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelection);
    if (_selected.isNotEmpty) _current = (_selected.toList()..sort()).first;
    _open();
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final doc = await PdfDocument.openFile(widget.file.path);
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _pageCount = doc.pagesCount;
        _selected.removeWhere((p) => p > _pageCount);
        if (_current > _pageCount) _current = 1;
      });
      _ensureThumb(_current);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _ensureThumb(int page) {
    if (_doc == null || _thumbs.containsKey(page)) return;
    _renderChain = _renderChain.then((_) => _renderThumb(page));
  }

  Future<void> _renderThumb(int page) async {
    final doc = _doc;
    if (doc == null || _thumbs.containsKey(page) || !mounted) return;
    try {
      final p = await doc.getPage(page);
      // Render wide enough to read the page, but not so large that a long
      // document eats memory. Height scales with the page's own ratio.
      const targetWidth = 1000.0;
      final scale = targetWidth / p.width;
      final img = await p.render(
        width: p.width * scale,
        height: p.height * scale,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await p.close();
      if (img != null && mounted) {
        setState(() => _thumbs[page] = img.bytes);
      }
    } catch (_) {
      // Leave it uncached; the preview shows a spinner for this page.
    }
  }

  void _goTo(int page) {
    if (page < 1 || page > _pageCount) return;
    setState(() => _current = page);
    _ensureThumb(page);
  }

  void _toggleCurrent() {
    setState(() {
      if (!_selected.remove(_current)) _selected.add(_current);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Cap the height so the Image page stays visible, dimmed, above and below
    // the card (Markus, 2026-07-16: it should read as a modal, not a new page).
    final maxHeight = MediaQuery.of(context).size.height * 0.82;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child:
              _failed
                  ? _errorBody(loc)
                  : _doc == null
                  ? const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  )
                  : _selectorBody(loc),
        ),
      ),
    );
  }

  Widget _errorBody(AppLocalizations loc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          loc.imageNotClearBody,
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoCondensed(fontSize: 18),
        ),
        const SizedBox(height: 24),
        _pillButton(
          label: loc.cancel,
          color: _navRed,
          onTap: () => Navigator.of(context).pop<List<int>?>(null),
        ),
      ],
    );
  }

  Widget _selectorBody(AppLocalizations loc) {
    return Column(
      children: [
        Text(
          widget.convertedFrom == null
              ? 'pdf-importer'
              : loc.documentImporterTitle,
          style: GoogleFonts.robotoCondensed(
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.convertedFrom != null) ...[
          Text(
            loc.convertedToPdfNote(widget.convertedFrom!),
            textAlign: TextAlign.center,
            style: GoogleFonts.robotoCondensed(fontSize: 18, height: 1.25),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          loc.pdfImporterInstruction(_pageCount),
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoCondensed(fontSize: 18, height: 1.25),
        ),
        const SizedBox(height: 16),
        Expanded(child: _pager()),
        const SizedBox(height: 12),
        Text(
          loc.pdfPageCounter(_current, _pageCount),
          style: GoogleFonts.robotoCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _pillButton(
                label: loc.cancel,
                color: _navRed,
                onTap: () => Navigator.of(context).pop<List<int>?>(null),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _pillButton(
                label: loc.ok,
                color: _navGreen,
                onTap:
                    _selected.isEmpty
                        ? null
                        : () {
                          final pages = _selected.toList()..sort();
                          Navigator.of(context).pop<List<int>?>(pages);
                        },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pager() {
    return Row(
      children: [
        _arrow(
          asset: 'assets/png24/black/b_arrow_left.png',
          enabled: _current > 1,
          onTap: () => _goTo(_current - 1),
        ),
        Expanded(child: _pagePreview()),
        _arrow(
          asset: 'assets/png24/black/b_arrow_right.png',
          enabled: _current < _pageCount,
          onTap: () => _goTo(_current + 1),
        ),
      ],
    );
  }

  Widget _arrow({
    required String asset,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Image.asset(asset, width: 34, height: 34),
        ),
      ),
    );
  }

  Widget _pagePreview() {
    final bytes = _thumbs[_current];
    final checked = _selected.contains(_current);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Positioned.fill(
            child:
                bytes == null
                    ? const Center(child: CircularProgressIndicator())
                    : Image.memory(bytes, fit: BoxFit.contain),
          ),
          // "Check them with click in the corner." The tick sits in the
          // bottom-right of the page, matching Markus's mock-up.
          Positioned(
            right: 8,
            bottom: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleCurrent,
              child: Image.asset(
                checked
                    ? 'assets/png24/black/b_checkbox_checked.png'
                    : 'assets/png24/black/b_checkbox_empty.png',
                width: 52,
                height: 52,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.robotoCondensed(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
