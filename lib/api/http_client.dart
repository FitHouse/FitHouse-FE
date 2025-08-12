import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

const String _baseAndroid = 'http://10.0.2.2:8080';
const String _baseOther = 'http://localhost:8080';

String get baseUrl => Platform.isAndroid ? _baseAndroid : _baseOther;

Future<Map<String, String>> authHeaders({bool json = true}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('로그인이 필요합니다.');
  }
  final token = await user.getIdToken(true);
  return {
    if (json) 'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

final http.Client httpClient = http.Client();
