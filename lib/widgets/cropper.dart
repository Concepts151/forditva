import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img; // Alias for clarity
import 'package:path_provider/path_provider.dart';

import '../flutter_gen/gen_l10n/app_localizations.dart';

const Color navRed = Color(0xFFCD2A3E);
const Color navGreen = Color(0xFF436F4D);

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
      if (mounted) setState(() => _decodedImage = decoded);
    });
  }

  Future<File?> _cropImageToPolygon(
    // Renamed to a private method for clarity
    File imageFile,
    List<Offset> points, {
    double drawW = 350,
    double drawH = 350,
  }) async {
    // 1. Load original image bytes and decode
    final bytes = await imageFile.readAsBytes();
    final img.Image? orig = img.decodeImage(bytes);
    if (orig == null) {
      debugPrint('Error: Could not decode image.');
      return null;
    }

    final int imgW = orig.width;
    final int imgH = orig.height;

    // 2. Scale points from UI coordinates to image pixel coordinates
    final double scaleX = imgW / drawW;
    final double scaleY = imgH / drawH;
    final polygon =
        points
            .map(
              (pt) =>
                  img.Point((pt.dx * scaleX).toInt(), (pt.dy * scaleY).toInt()),
            )
            .toList();

    // 3. Create a blank mask image with the same dimensions as the original image.
    // Use named parameters for width and height.
    final mask = img.Image(width: imgW, height: imgH);

    // 4. Fill the mask with fully transparent black (0x00000000).
    // Use img.ColorRgba8 for the color argument.
    img.fill(mask, color: img.ColorRgba8(0, 0, 0, 0));

    // 5. Fill the polygon area on the mask with fully opaque white (0xFFFFFFFF).
    // This defines the area that will be kept from the original image.
    // The list of points must be passed using the 'vertices' named parameter.
    img.fillPolygon(
      mask,
      vertices: polygon,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // 6. Apply the mask to the original image.
    // Create a new image from the original to avoid modifying the source directly.
    final out = img.Image.from(orig);
    for (int y = 0; y < imgH; y++) {
      for (int x = 0; x < imgW; x++) {
        // Get the pixel from the mask image.
        final maskPixel = mask.getPixel(x, y);
        // Extract the alpha component directly from the Pixel object using its 'a' property.
        // If alpha is 0 (fully transparent), set the corresponding pixel in the output
        // image to fully transparent. This effectively 'cuts out' the unmasked areas.
        final a = maskPixel.a; // Correctly access alpha from Pixel object
        if (a == 0) {
          out.setPixelRgba(
            x,
            y,
            0,
            0,
            0,
            0,
          ); // Clear pixel in result (fully transparent)
        }
      }
    }
    // ... after applying mask ...

    // Bounding box calculation for cropping to the minimal size
    int minX = polygon.map((p) => p.x as int).reduce((a, b) => a < b ? a : b);
    int maxX = polygon.map((p) => p.x as int).reduce((a, b) => a > b ? a : b);
    int minY = polygon.map((p) => p.y as int).reduce((a, b) => a < b ? a : b);
    int maxY = polygon.map((p) => p.y as int).reduce((a, b) => a > b ? a : b);

    // Clamp bounding box to image dimensions
    minX = minX.clamp(0, imgW - 1);
    maxX = maxX.clamp(0, imgW - 1);
    minY = minY.clamp(0, imgH - 1);
    maxY = maxY.clamp(0, imgH - 1);

    final cropWidth = maxX - minX + 1;
    final cropHeight = maxY - minY + 1;

    // Crop the image to the calculated bounding box
    final cropped = img.copyCrop(
      out,
      x: minX,
      y: minY,
      width: cropWidth,
      height: cropHeight,
    );

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/crop_result_${DateTime.now().millisecondsSinceEpoch}.png';
    debugPrint('Cropped image saved at: $outPath');

    final outFile = File(outPath);

    // Write the cropped image to a file
    await outFile.writeAsBytes(img.encodePng(cropped));

    // Share the cropped image
    //final xFile = XFile(outFile.path);
    ///Share.shareXFiles([xFile], text: 'Cropped image result');

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
                width: 64,
                height: 64,
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
                width: 64,
                height: 64,
              ),
            ),
          ),
          // Instruction text (center bottom)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 100,
                  vertical: 10,
                ),
                child: Text(
                  AppLocalizations.of(context)!.cropInstruction,
                  style: GoogleFonts.robotoCondensed(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
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
