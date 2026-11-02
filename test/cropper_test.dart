import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/widgets/cropper.dart';
import 'package:image/image.dart' as img;

void main() {
  _pngTest();
  _instructionTest();
  // A 3-channel photo (like a JPEG), all red.
  img.Image redPhoto() {
    final photo = img.Image(width: 100, height: 100);
    img.fill(photo, color: img.ColorRgb8(255, 0, 0));
    return photo;
  }

  test('the area outside the outline is white, inside stays', () {
    // A triangle: top-left corner of the bounding box lies outside it.
    final polygon = [img.Point(10, 10), img.Point(90, 90), img.Point(10, 90)];
    final result = cutOutPolygon(redPhoto(), polygon);

    expect(result.width, 81);
    expect(result.height, 81);
    // Top-right corner of the box: outside the triangle.
    final outside = result.getPixel(78, 2);
    expect([outside.r, outside.g, outside.b, outside.a], [255, 255, 255, 255]);
    // Bottom-left area: inside the triangle.
    final inside = result.getPixel(10, 70);
    expect([inside.r, inside.g, inside.b, inside.a], [255, 0, 0, 255]);
  });

  test('a transparent PNG source gets the same white outside', () {
    final photo = img.Image(width: 50, height: 50, numChannels: 4);
    img.fill(photo, color: img.ColorRgba8(0, 0, 255, 255));
    final polygon = [img.Point(5, 5), img.Point(45, 5), img.Point(5, 45)];
    final result = cutOutPolygon(photo, polygon);
    final outside = result.getPixel(38, 38);
    expect([outside.r, outside.g, outside.b, outside.a], [255, 255, 255, 255]);
  });
}

void _pngTest() {
  test('cropToPolygonPng returns a PNG of the outline box', () {
    final photo = img.Image(width: 200, height: 100);
    img.fill(photo, color: img.ColorRgb8(10, 20, 30));
    final bytes = img.encodeJpg(photo);
    // Outline in a 100 x 50 drawing area: scale 2 to the photo.
    final png = cropToPolygonPng(
      bytes,
      [10, 10, 40, 10, 40, 30, 10, 30],
      100,
      50,
    );
    final result = img.decodePng(png!)!;
    expect(result.width, 61);
    expect(result.height, 41);
    expect(cropToPolygonPng(Uint8List(5), [0, 0], 1, 1), isNull);
  });
}

void _instructionTest() {
  const texts = {
    'de': [
      'Was möchtest du übersetzen?',
      'Kreise den gewünschten Bereich ein oder tippe auf OK für das ganze Bild.',
    ],
    'en': [
      'What would you like to translate?',
      'Circle the desired area or tap OK to translate the entire image.',
    ],
    'hu': [
      'Mit szeretnél lefordítani?',
      'Karikázd be a kívánt részt, vagy nyomj OK-t a teljes képhez.',
    ],
  };
  // Tests draw with the square Ahem font (every letter 1 em wide); Roboto
  // Condensed is about 0.42 em, so the sizes are scaled down to match.
  const titleStyle = TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700);
  const bodyStyle = TextStyle(fontSize: 6.7, fontWeight: FontWeight.w500);

  for (final entry in texts.entries) {
    for (final width in [190.0, 220.0, 260.0]) {
      test('instruction fits 1 + 2 lines: ${entry.key} at $width', () {
        final k = cropInstructionScale(
          title: entry.value[0],
          body: entry.value[1],
          width: width,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
        );
        expect(k, inInclusiveRange(0.55, 1.0));
        int lines(String text, TextStyle style, int max) {
          final p = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            maxLines: max,
          )..layout(maxWidth: width);
          return p.didExceedMaxLines ? max + 1 : max;
        }

        expect(
          lines(entry.value[0], titleStyle.copyWith(fontSize: 7.5 * k), 1),
          1,
        );
        expect(
          lines(entry.value[1], bodyStyle.copyWith(fontSize: 6.7 * k), 2),
          lessThanOrEqualTo(2),
        );
      });
    }
  }
}
