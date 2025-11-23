import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:fithouse/api/http_client.dart';

class FamilyEditScreen extends StatefulWidget {
  const FamilyEditScreen({super.key});

  @override
  State<FamilyEditScreen> createState() => _FamilyEditScreenState();
}

class _FamilyEditScreenState extends State<FamilyEditScreen> {
  final _nameCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  String? _currentImageUrl;
  File? _newImageFile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
  }

  Future<void> _loadFamilyInfo() async {
    try {
      final uri = Uri.parse("$baseUrl/family/mine");
      final res = await httpClient.get(uri, headers: await authHeaders());

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));

        setState(() {
          _nameCtrl.text = data["familyName"] ?? "";
          _commentCtrl.text = data["familyComment"] ?? "";
          _currentImageUrl = data["familyImageUrl"];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final uri = Uri.parse("$baseUrl/family");

      final bodyData = {
        "familyName": _nameCtrl.text.trim(),
        "familyComment": _commentCtrl.text.trim(),
      };

      http.Response res;

      if (_newImageFile == null) {
        final headers = {
          'Content-Type': 'application/json',
          ...(await authHeaders()),
        };
        res = await httpClient.put(
          uri,
          headers: headers,
          body: jsonEncode(bodyData),
        );
      }
      else {
        final req = http.MultipartRequest("PUT", uri);
        req.headers.addAll(await authHeaders());

        req.fields["body"] = jsonEncode(bodyData);

        req.files.add(
          await http.MultipartFile.fromPath("file", _newImageFile!.path),
        );

        final streamed = await req.send();
        res = await http.Response.fromStream(streamed);
      }

      if (res.statusCode == 200) {
        Navigator.pop(context);
      } else {
        print("상태코드: ${res.statusCode}");
        print("BODY: ${res.body}");
        throw Exception("가족 정보 수정 실패");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    ImageProvider<Object>? imageProvider;

    if (_newImageFile != null) {
      imageProvider = FileImage(_newImageFile!);
    } else if (_currentImageUrl != null) {
      imageProvider = NetworkImage("$assetBaseUrl$_currentImageUrl");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("가족 정보 수정"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    // 프로필 이미지 (기본 이미지 + 테두리)
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: imageProvider != null
                            ? Image(
                          image: imageProvider!,
                          fit: BoxFit.cover,
                        )
                            : const Icon(
                          Icons.group,
                          color: Colors.green,
                          size: 42,
                        ),
                      ),
                    ),

                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _nameCtrl,
              maxLength: 30,
              buildCounter: (
                  BuildContext context, {
                    required int currentLength,
                    required int? maxLength,
                    required bool isFocused,
                  }) {
                return Text(
                  "$currentLength/$maxLength",
                  style: TextStyle(
                    fontSize: 12,
                    color: isFocused ? Colors.green : Colors.grey,
                  ),
                );
              },
              decoration: const InputDecoration(
                labelText: "가족 이름",
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2),
                ),
                floatingLabelStyle: TextStyle(color: Colors.green),
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: _commentCtrl,
              maxLines: 2,
              maxLength: 50,
              buildCounter: (
                  BuildContext context, {
                    required int currentLength,
                    required int? maxLength,
                    required bool isFocused,
                  }) {
                return Text(
                  "$currentLength/$maxLength",
                  style: TextStyle(
                    fontSize: 12,
                    color: isFocused ? Colors.green : Colors.grey,
                  ),
                );
              },
              decoration: const InputDecoration(
                labelText: "가족 소개",
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2),
                ),
                floatingLabelStyle: TextStyle(color: Colors.green),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "저장하기",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
