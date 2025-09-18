import 'package:flutter/services.dart' show rootBundle;

class LegalDocsLoader {
  static String? _privacyCache;
  static String? _termsCache;

  static Future<String> loadPrivacyKo() async {
    if (_privacyCache != null) return _privacyCache!;
    _privacyCache = await rootBundle.loadString('assets/docs/privacy_ko.md');
    return _privacyCache!;
  }

  static Future<String> loadTermsKo() async {
    if (_termsCache != null) return _termsCache!;
    _termsCache = await rootBundle.loadString('assets/docs/terms_ko.md');
    return _termsCache!;
  }
}