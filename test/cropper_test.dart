import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/widgets/cropper.dart';
import 'package:image/image.dart' as img;

void main() {
  _pngTest();
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
