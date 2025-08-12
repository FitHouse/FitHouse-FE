import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:fithouse/models/user_entity.dart';

class AuthApi {
  static const String _base = 'http://marketalert.iptime.org:8080';

  static Future<void> registerFirebaseWithProfile({
    required String idToken,
    required String name,
    required String email,
    required Gender gender,
    required String birthdate,
    required double height,
    required double weight,
    required Role role,
  }) async {
    final uri = Uri.parse('$_base/api/auth/firebase/register');

    final bodyMap = {
      'idToken': idToken,
      'name': name,
      'email': email,
      'gender': gender.name,
      'birthdate': birthdate,
      'height': height,
      'weight': weight,
      'role': role.name,
    };
    final body = jsonEncode(bodyMap);

    if (kDebugMode) {
      debugPrint('AuthApi - Sending request to: $uri');
      debugPrint('AuthApi - Request body: $body');
    }

    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (kDebugMode) {
        debugPrint('AuthApi - Received response: ${resp.statusCode}');
        debugPrint('AuthApi - Response body: ${resp.body}');
      }

      if (resp.statusCode >= 400) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthApi - NETWORK_ERROR: $e');
      }
      throw Exception('NETWORK_ERROR: $e');
    }
  }
  static Future<String> uploadProfileImage({
    required File imageFile,
    required String firebaseUid,
  }) async {
    final uri = Uri.parse('$_base/api/user/profile/image');

    final request = http.MultipartRequest('POST', uri)
      ..fields['firebaseUid'] = firebaseUid
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      );

    if (kDebugMode) {
      debugPrint('AuthApi - Uploading image to: $uri');
      debugPrint('AuthApi - Filename: ${imageFile.path.split('/').last}');
    }

    try {
      final response = await request.send();

      final responseBody = await response.stream.bytesToString();
      if (kDebugMode) {
        debugPrint('AuthApi - Image upload response: ${response.statusCode}');
        debugPrint('AuthApi - Response body: $responseBody');
      }

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception('이미지 업로드 서버 오류: HTTP ${response.statusCode}, Body: $responseBody');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthApi - IMAGE_UPLOAD_ERROR: $e');
      }
      throw Exception('IMAGE_UPLOAD_ERROR: $e');
    }
  }
}