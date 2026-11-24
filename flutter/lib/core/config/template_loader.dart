import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads the bundled sing-box template asset.
///
/// The asset is kept in sync with `client/shared/singbox-template.json`
/// (repo root, shared by both clients). Template changes ship with the app
/// version — never via remote download, so a tampered template cannot be
/// pushed to clients.
class TemplateLoader {
  const TemplateLoader({this.assetPath = 'assets/singbox-template.json'});

  final String assetPath;

  Future<Map<String, dynamic>> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('模板不是 JSON 对象');
    }
    return decoded;
  }
}
