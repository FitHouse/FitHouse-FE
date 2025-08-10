// /api/auth_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  static const String _base = 'http://marketalert.iptime.org:8080';

  static Future<void> registerFirebaseWithProfile({
    required String idToken,
    required String name,
    String? email,
  }) async {
    final uri = Uri.parse('$_base/api/auth/firebase/register');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'idToken': idToken,
        'name': name,
        if (email != null) 'email': email,
      }),
    );

    if (resp.statusCode >= 400) {
      throw Exception('서버 오류(${resp.statusCode}): ${resp.body}');
    }
  }
}
