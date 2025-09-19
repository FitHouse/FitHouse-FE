import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../api/http_client.dart' show baseUrl;

class UserProfileApi {
  UserProfileApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UserProfile> fetchMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final idToken = await user.getIdToken();

    final res = await _client.get(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load profile: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final idToken = await user.getIdToken();

    final res = await _client.patch(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update profile: ${res.statusCode}');
    }

    return UserProfile.fromJson(jsonDecode(res.body));
  }

  Future<UserProfile> uploadProfileImage(String filePath) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final idToken = await user.getIdToken();

    final uri = Uri.parse('$baseUrl/api/users/me/profile-image');
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $idToken'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final res = await request.send();
    final responseBody = await res.stream.bytesToString();

    if (res.statusCode != 200) {
      throw Exception('Failed to upload image: ${res.statusCode} - $responseBody');
    }
    return UserProfile.fromJson(jsonDecode(responseBody));
  }

  Future<void> deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final idToken = await user.getIdToken();

    final res = await _client.delete(
      Uri.parse('$baseUrl/api/users/me/profile-image'),
      headers: {
        'Authorization': 'Bearer $idToken',
      },
    );

    if (res.statusCode != 204) {
      throw Exception('Failed to delete image: ${res.statusCode}');
    }
  }

  Future<UserProfile> leaveFamily() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final idToken = await user.getIdToken();

    final res = await _client.delete(
      Uri.parse('$baseUrl/api/users/me/family'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Accept': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    }

    if (res.statusCode == 204) {
      return fetchMe();
    }

    throw Exception('Failed to leave family: ${res.statusCode} - ${res.body}');
  }

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final idToken = await user.getIdToken();
    final res = await _client.delete(
      Uri.parse('$baseUrl/api/users/me'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 204) {
      throw Exception('Failed to delete account: ${res.statusCode} ${res.body}');
    }
  }
}
