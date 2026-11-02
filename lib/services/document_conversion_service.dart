import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ConversionErrorKind {
  /// The server rejected or failed to convert the file (corrupted,
  /// password-protected, unsupported formatting, or the request timed out).
  conversionFailed,

  /// No connection, timeout, or unreadable response.
  network,

  /// Server misconfiguration (base URL not set).
  config,
}

class DocumentConversionException implements Exception {
  final ConversionErrorKind kind;
  final String message;
  DocumentConversionException(this.kind, this.message);

  @override
  String toString() => 'DocumentConversionException($kind): $message';
}

/// Converts an Office/text document (doc, docx, xls, xlsx, odt, ods, txt) to
/// PDF via our own LibreOffice-backed conversion service, so it can go
/// through the exact same PDF flow (page picker, then Gemini) as a directly
/// uploaded PDF. Gemini's inline_data only accepts images and PDF natively,
/// this is the workaround for everything else (Markus, 2026-08 proposal).
///
/// The server is Andy's deployment at [defaultConversionBaseUrl] (live
/// 2026-10-23). CONVERSION_API_BASE_URL in `.env` overrides it, for testing
/// against another server.
class DocumentConversionService {
  static const defaultConversionBaseUrl = 'https://convert.wir-in-ungarn.hu';

  String get _baseUrl {
    final fromEnv = (dotenv.env['CONVERSION_API_BASE_URL'] ?? '').trim();
    return fromEnv.isNotEmpty ? fromEnv : defaultConversionBaseUrl;
  }

  /// The Image page only offers Office formats when this is true.
  bool get isConfigured => _baseUrl.isNotEmpty;

  /// Uploads [sourceFile] and returns a temp file containing the converted
  /// PDF. Throws [DocumentConversionException] on any failure.
  Future<File> convertToPdf(File sourceFile) async {
    if (_baseUrl.isEmpty) {
      throw DocumentConversionException(
        ConversionErrorKind.config,
        'CONVERSION_API_BASE_URL is not set',
      );
    }

    // Play Integrity (Android) / App Attest (iOS) token proving this request
    // comes from a genuine, unmodified install — no bundled secret involved,
    // the server verifies this against Firebase (Markus, 2026-08: "we should
    // not use a bundled static API key").
    final String appCheckToken;
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token == null) {
        throw DocumentConversionException(
          ConversionErrorKind.config,
          'App Check token unavailable (Firebase not configured yet)',
        );
      }
      appCheckToken = token;
    } on DocumentConversionException {
      rethrow;
    } catch (e) {
      throw DocumentConversionException(
        ConversionErrorKind.config,
        'App Check token unavailable: $e',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/convert/to-pdf'),
    )..headers['X-Firebase-AppCheck'] = appCheckToken;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        sourceFile.path,
        filename: p.basename(sourceFile.path),
      ),
    );

    http.StreamedResponse streamed;
    try {
      // The server gives LibreOffice up to 90 s; wait a little longer so
      // its own answer arrives rather than our timeout.
      streamed = await request.send().timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw DocumentConversionException(
        ConversionErrorKind.network,
        'Conversion request timed out',
      );
    } catch (e) {
      throw DocumentConversionException(
        ConversionErrorKind.network,
        'Network error: $e',
      );
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw DocumentConversionException(
        ConversionErrorKind.conversionFailed,
        'Conversion failed: ${response.statusCode}',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(sourceFile.path);
    final pdfFile = File(
      p.join(
        tempDir.path,
        '${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await pdfFile.writeAsBytes(response.bodyBytes, flush: true);
    return pdfFile;
  }
}
