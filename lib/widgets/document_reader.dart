import 'package:flutter/material.dart';

/// Full-screen, upright view of a File page result. The landscape zoom
/// view suits one sentence shown to someone across the table, but it put a
/// whole document sideways at 48 px with every segment run together, so
/// the File page's expand icon opens this instead (2026-10-25).
///
/// [builder] draws the result the same way as the File page panel, at the
/// given zoom and height. One-finger drags scroll; a two-finger pinch
/// zooms, observed with raw pointers like the panel so scrolling stays
/// untouched.
class DocumentReader extends StatefulWidget {
  const DocumentReader({super.key, required this.builder});

  final Widget Function(double zoom, double height) builder;

  @override
  State<DocumentReader> createState() => _DocumentReaderState();
}

class _DocumentReaderState extends State<DocumentReader> {
  final _scrollController = ScrollController();
  final Map<int, Offset> _pointers = {};
  double? _pinchStartDistance;
  double _pinchStartZoom = 1.0;

  /// Starts a bit larger than the panel: the reader has the whole screen.
  double _zoom = 1.25;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final points = _pointers.values.toList();
      _pinchStartDistance = (points[0] - points[1]).distance;
      _pinchStartZoom = _zoom;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final startDistance = _pinchStartDistance;
    if (_pointers.length == 2 && startDistance != null && startDistance > 0) {
      final points = _pointers.values.toList();
      final distance = (points[0] - points[1]).distance;
      setState(() {
        _zoom = (_pinchStartZoom * distance / startDistance).clamp(0.8, 3.0);
      });
    }
  }

  void _onPointerUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder:
                  (context, constraints) => Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        // Top space keeps the first line clear of the close
                        // icon.
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
                        child: widget.builder(_zoom, constraints.maxHeight),
                      ),
                    ),
                  ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Image.asset(
                  'assets/images/close.png',
                  width: 40,
                  height: 40,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
