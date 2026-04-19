import 'dart:io';
import '../models/contact.dart';

class TemplateService {
  static String applyTemplate(String template, Contact contact,
      {Map<String, String>? extra}) {
    var result = template;
    for (final entry in contact.fields.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
      result = result.replaceAll('{{${entry.key.toUpperCase()}}}', entry.value);
      result = result.replaceAll('{{${entry.key.toLowerCase()}}}', entry.value);
    }
    if (extra != null) {
      for (final entry in extra.entries) {
        result = result.replaceAll('{{${entry.key}}}', entry.value);
      }
    }
    return result;
  }

  static Future<String> loadHtmlFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('Fichier introuvable: $path');
    return await file.readAsString();
  }

  static List<String> extractPlaceholders(String template) {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    return regex
        .allMatches(template)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
  }

  static String buildHtmlBody(String content) {
    if (content.trim().toLowerCase().startsWith('<!doctype') ||
        content.trim().toLowerCase().startsWith('<html')) {
      return content;
    }
    return '''<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px;">
$content
</body>
</html>''';
  }
}
