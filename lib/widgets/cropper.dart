import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img; // Alias for clarity
import 'package:path_provider/path_provider.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';

const Color navRed = Color(0xFFCD2A3E);

/// Size of the ✗ and ✓ buttons under the photo (was 64; Markus, 2026-11-02:
/// "the two buttons are too massive").
const double _cropButtonSize = 50;
const Color navGreen = Color(0xFF436F4D);

/// The part of [orig] inside [polygon], cut to the polygon's bounding box,
/// with everything outside the outline (but inside the box) painted white.
///
/// The old mask was a 3-channel image, whose alpha reads as 255 everywhere, so
/// nothing outside the outline was ever removed: the AI got the whole bounding
/// box and translated text the user had left out (Markus, 2026-11-02: the
/// engraved name labels above his selection).
img.Image cutOutPolygon(img.Image orig, List<img.Point> polygon) {
  int minX = polygon.map((p) => p.x.toInt()).reduce((a, b) => a < b ? a : b);
  int maxX = polygon.map((p) => p.x.toInt()).reduce((a, b) => a > b ? a : b);
  int minY = polygon.map((p) => p.y.toInt()).reduce((a, b) => a < b ? a : b);
  int maxY = polygon.map((p) => p.y.toInt()).reduce((a, b) => a > b ? a : b);
  minX = minX.clamp(0, orig.width - 1);
  maxX = maxX.clamp(0, orig.width - 1);
  minY = minY.clamp(0, orig.height - 1);
  maxY = maxY.clamp(0, orig.height - 1);

  final out = img.copyCrop(
    orig.numChannels == 4 ? orig : orig.convert(numChannels: 4),
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  // The outline in the cut-out's own coordinates, drawn on a mask WITH an
  // alpha channel: opaque inside, transparent outside.
  final mask = img.Image(width: out.width, height: out.height, numChannels: 4);
  img.fill(mask, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillPolygon(
    mask,
    vertices: [
      for (final p in polygon)
        img.Point(p.x.toInt() - minX, p.y.toInt() - minY),
    ],
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      if (mask.getPixel(x, y).a == 0) {
        out.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }
  return out;
}

/// Decodes [bytes], cuts out the outline given as x,y pairs in the drawing
/// area's coordinates ([drawW] x [drawH]) and returns the result as a PNG, or
/// null when the photo can't be decoded. Runs in a background isolate.
Uint8List? cropToPolygonPng(
  Uint8List bytes,
  List<double> flatPoints,
  double drawW,
  double drawH,
) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // The decoder throws on damaged files instead of answering null.
    return null;
  }
  if (decoded == null) return null;
  // Upright first: the preview shows the photo upright (Flutter honors the
  // EXIF rotation), so the outline is in those coordinates.
  final orig = img.bakeOrientation(decoded);
  final scaleX = orig.width / drawW;
  final scaleY = orig.height / drawH;
  final polygon = [
    for (var i = 0; i + 1 < flatPoints.length; i += 2)
      img.Point(
        (flatPoints[i] * scaleX).toInt(),
        (flatPoints[i + 1] * scaleY).toInt(),
      ),
  ];
  return img.encodePng(cutOutPolygon(orig, polygon));
}

class ImageCropperPage extends StatefulWidget {
  final File imageFile;

  const ImageCropperPage({super.key, required this.imageFile});

  @override
  State<ImageCropperPage> createState() => _ImageCropperPageState();
}

class _ImageCropperPageState extends State<ImageCropperPage> {
  List<Offset> _points = [];
  img.Image? _decodedImage;

  bool _isProcessing = false; // Changed to mutable

  // Responsive sizing
  /// Crops the given image file to the specified polygon shape.
  ///
  /// [imageFile]: The original image file to be cropped.
  /// [points]: A list of Offsets representing the polygon points in UI coordinates.
  /// [drawW], [drawH]: The width and height of the drawing area where the points were collected.
  ///
  /// Returns a Future that resolves to the cropped File, or null if an error occurs.
  ///
  @override
  void initState() {
    super.initState();
    // Decode once at startup for aspect ratio and drawing
    widget.imageFile.readAsBytes().then((bytes) {
      final decoded = img.decodeImage(bytes);
      if (mounted) {
        setState(
          () =>
              _decodedImage =
                  decoded == null ? null : img.bakeOrientation(decoded),
        );
      }
    });
  }

  Future<File?> _cropImageToPolygon(
    File imageFile,
    List<Offset> points, {
    double drawW = 350,
    double drawH = 350,
  }) async {
    final bytes = await imageFile.readAsBytes();
    // Decoding, cutting and encoding a 12 MP photo takes seconds; on the main
    // thread it froze the spinner, so Markus saw no feedback after tapping
    // the check mark (2026-11-02).
    final flat = [
      for (final p in points) ...[p.dx, p.dy],
    ];
    final png = await Isolate.run(
      () => cropToPolygonPng(bytes, flat, drawW, drawH),
    );
    if (png == null) {
      debugPrint('Error: Could not decode image.');
      return null;
    }
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/crop_result_${DateTime.now().millisecondsSinceEpoch}.png';
    debugPrint('Cropped image saved at: $outPath');
    final outFile = File(outPath);
    await outFile.writeAsBytes(png);
    return outFile;
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_decodedImage == null) {
      // Still loading image
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final screenW = MediaQuery.of(context).size.width;
    final double sidePadding = 6.0;
    final double cropBoxWidth = screenW - 2 * sidePadding;
    final double imgW = _decodedImage!.width.toDouble();
    final double imgH = _decodedImage!.height.toDouble();
    final double aspectRatio = imgW / imgH;
    final double cropBoxHeight = cropBoxWidth / aspectRatio; // dynamic!

    return Scaffold(
      body: Stack(
        children: [
          // Background image fills entire page
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg-image.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Centered image box with drawing area
          Center(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 100,
                top: 20,
              ), // adjust as needed
              child: SizedBox(
                width: cropBoxWidth,
                height: cropBoxHeight,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.fill,
                        width: cropBoxWidth,
                        height: cropBoxHeight,
                      ),
                    ),
                    GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _points = [details.localPosition];
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _points = List.from(_points)
                            ..add(details.localPosition);
                        });
                      },
                      // Lifting the finger closes the shape with a straight
                      // line back to the start (Markus, 2026-10-29: being one
                      // or two pixels off the start rejected the whole
                      // outline).
                      onPanEnd: (_) {
                        if (_points.length < 3) return;
                        setState(() {
                          _points = List.from(_points)..add(_points.first);
                        });
                      },
                      child: CustomPaint(
                        painter: _FreehandPainter(_points),
                        size: Size(cropBoxWidth, cropBoxHeight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ✓ (Check) button (bottom right, on page)
          Positioned(
            bottom: 36,
            right: 24,
            child: GestureDetector(
              onTap: () async {
                if (_points.length < 3) {
                  // If not enough points, just return the original image
                  Navigator.of(context).pop(widget.imageFile);
                  return;
                }
                // Closed when the finger lifted; close it here too in case
                // the last stroke had not ended yet.
                final pointsToCrop = List<Offset>.from(_points);
                if (pointsToCrop.last != pointsToCrop.first) {
                  pointsToCrop.add(pointsToCrop.first);
                }

                // Set processing state to true to show loading indicator
                setState(() {
                  _isProcessing = true;
                });

                // Call the corrected _cropImageToPolygon method with the (potentially closed) points
                final croppedFile = await _cropImageToPolygon(
                  widget.imageFile,
                  pointsToCrop, // Use the modified list for cropping
                  drawW: cropBoxWidth,
                  drawH: cropBoxHeight,
                );

                // Set processing state back to false
                if (mounted) {
                  setState(() {
                    _isProcessing = false;
                  });
                }

                if (croppedFile != null && context.mounted) {
                  Navigator.of(context).pop(croppedFile); // Return cropped file
                }
              },
              // The app's own asset icons already are rounded-square, colored
              // buttons — no extra Container/Icon needed, same as every other
              // confirm/cancel pair in the app (Markus, 2026-07-10: "these
              // are not our icons").
              child: Image.asset(
                'assets/images/check_green.png',
                width: _cropButtonSize,
                height: _cropButtonSize,
              ),
            ),
          ),
          // X (Clear) button (bottom left, on page)
          Positioned(
            bottom: 36,
            left: 24,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _points = []; // Clear all drawn points
                });
              },
              child: Image.asset(
                'assets/images/close_red.png',
                width: _cropButtonSize,
                height: _cropButtonSize,
              ),
            ),
          ),
          // Instruction text, centered between the two buttons. Markus,
          // 2026-11-02: first line Roboto Condensed Bold, the other lines
          // Medium and 2 px smaller; the buttons smaller.
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: SizedBox(
              height: _cropButtonSize,
              child: OverflowBox(
                maxHeight: 110,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 86),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.cropInstruction,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.cropInstructionBody,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoCondensed(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter for drawing freehand lines based on a list of Offsets.
class _FreehandPainter extends CustomPainter {
  final List<Offset> points;
  _FreehandPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.red.withValues(
            alpha: 0.7,
          ) // Semi-transparent red line
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FreehandPainter old) => old.points != points;
}
