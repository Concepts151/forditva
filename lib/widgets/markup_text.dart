import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Turns the small markup in the welcome texts into a [TextSpan]:
/// `**bold**` and `[label](https://link)` (opens in the browser).
TextSpan markupSpan(String text) {
  final pattern = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)');
  final spans = <InlineSpan>[];
  var pos = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      final url = Uri.parse(m.group(3)!);
      spans.add(
        TextSpan(
          text: m.group(2),
          style: const TextStyle(
            color: Color(0xFF1A5FB4),
            decoration: TextDecoration.underline,
          ),
          recognizer:
              TapGestureRecognizer()
                ..onTap =
                    () => launchUrl(url, mode: LaunchMode.externalApplication),
        ),
      );
    }
    pos = m.end;
  }
  if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
  return TextSpan(children: spans);
}
