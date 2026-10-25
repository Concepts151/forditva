import 'dart:io';

import 'package:flutter/material.dart';

class FreehandCropperPage extends StatefulWidget {
  final File imageFile;
  const FreehandCropperPage({super.key, required this.imageFile});

  @override
  State<FreehandCropperPage> createState() => _FreehandCropperPageState();
}

class _FreehandCropperPageState extends State<FreehandCropperPage> {
  List<Offset> _points = [];

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _points = [localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _points = List.from(_points)..add(localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Optionally: Close the path or do nothing (user can finish with a button)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg-image.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    // Show the image
                    Positioned.fill(
                      child: Image.file(widget.imageFile, fit: BoxFit.contain),
                    ),
                    // Drawing overlay
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart:
                            (details) => _onPanStart(details, constraints),
                        onPanUpdate:
                            (details) => _onPanUpdate(details, constraints),
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(painter: FreehandPainter(_points)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("Done"),
        icon: const Icon(Icons.check),
        onPressed: () {
          // Next: Crop logic
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class FreehandPainter extends CustomPainter {
  final List<Offset> points;
  FreehandPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FreehandPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
