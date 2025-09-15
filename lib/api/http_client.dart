import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// 배포 서버 주소 (API 호출용)
const String baseUrl = 'http://marketalert.iptime.org:8080';

// 정적 리소스 (이미지 등)
const String assetBaseUrl = 'http://marketalert.iptime.org:8080';

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

// 공용 HTTP 클라이언트
final http.Client httpClient = http.Client();

// 공통 요청 래퍼 (401 USER_NOT_FOUND 처리 예시 포함)
Future<http.Response> sendWithAuth(
    Future<http.Response> Function(Map<String, String>) run) async {
  final headers = await authHeaders();
  final res = await run(headers);

  if (res.statusCode == 401) {
    try {
      final body = jsonDecode(res.body);
      if (body['code'] == 'USER_NOT_FOUND') {
        await FirebaseAuth.instance.signOut();
        // navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } catch (_) {}
  }

  return res;
}

Future<http.Response> getJson(String url) {
  return sendWithAuth((headers) => httpClient.get(Uri.parse(url), headers: headers));
}

Future<http.Response> postJson(String url, Object body) {
  return sendWithAuth((headers) =>
      httpClient.post(Uri.parse(url), headers: headers, body: jsonEncode(body)));
}
