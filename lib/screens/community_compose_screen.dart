import 'dart:io';
import 'dart:convert';
import 'package:fithouse/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

const String kBaseUrl = 'http://marketalert.iptime.org:8080';

class CommunityComposeScreen extends StatefulWidget {
  final bool isEdit;
  final String? postId;
  final String? initialContent;
  final String? initialImageUrl;

  const CommunityComposeScreen.edit({
    super.key,
    required this.postId,
    required this.initialContent,
    this.initialImageUrl,
  }) : isEdit = true;

  const CommunityComposeScreen.create({
    super.key,
    this.initialContent,
    this.initialImageUrl,
  })  : isEdit = false,
        postId = null;

  @override
  State<CommunityComposeScreen> createState() => _CommunityComposeScreenState();
}

class _CommunityComposeScreenState extends State<CommunityComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _pickedImage;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl.text = widget.initialContent ?? '';
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<String> _authToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }
    final String? token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('ID 토큰을 가져오지 못했습니다.');
    }
    return token;
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _pickedImage = File(x.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        await _updatePost();
      } else {
        await _createPost();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPost() async {
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 등록해 주세요.')),
      );
      return;
    }

    final uri = Uri.parse('$kBaseUrl/api/community/photos');
    final token = await _authToken();

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['comment'] = _contentCtrl.text.trim();

    req.files.add(await http.MultipartFile.fromPath('file', _pickedImage!.path));

    final res = await req.send();
    final code = res.statusCode;
    if (code == 200 || code == 201) {
      if (!mounted) return;
      Navigator.pop(context, {'created': true});
    } else {
      final body = await res.stream.bytesToString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $code\n$body')),
      );
    }
  }

  Future<void> _updatePost() async {
    final uri = Uri.parse('$kBaseUrl/api/community/photos/${widget.postId}');
    final token = await _authToken();

    final newComment = _contentCtrl.text.trim();
    final hasImageChange = _pickedImage != null;
    final hasTextChange = (newComment != (widget.initialContent ?? '').trim());

    if (!hasImageChange && !hasTextChange) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경된 내용이 없습니다.')),
      );
      return;
    }

    final req = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';

    req.fields['comment'] = newComment;

    if (hasImageChange) {
      req.files.add(await http.MultipartFile.fromPath('file', _pickedImage!.path));
    }

    final streamed = await req.send();
    final code = streamed.statusCode;
    final body = await streamed.stream.bytesToString();

    if (code == 200) {
      String? newImageUrl;
      try {
        final m = jsonDecode(body) as Map<String, dynamic>;
        newImageUrl = (m['imageUrl'] as String?)?.trim();
      } catch (_) {
        // 응답 파싱 실패시 이미지 URL 없이 텍스트만 반영
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'updated': true,
        'content': newComment,
        if (newImageUrl != null && newImageUrl.isNotEmpty) 'newImageUrl': newImageUrl,
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: $code\n$body')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: naviGreen,
        title: Text(isEdit ? '게시글 수정' : '게시글 작성'),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(foregroundColor: naviGreen),
            child: _submitting
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(naviGreen),
              ),
            )
                : const Text('등록'),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (!isEdit) ...[
              GestureDetector(
                onTap: _pickImage,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: _pickedImage == null
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.image_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('사진을 등록해 주세요.'),
                        ],
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_pickedImage!, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // 수정 모드: 기존 이미지 보여주고 탭하면 교체 가능
              GestureDetector(
                onTap: _pickImage,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_pickedImage!, fit: BoxFit.cover),
                    )
                        : (widget.initialImageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.initialImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.image_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('사진을 등록해 주세요.'),
                        ],
                      ),
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  '탭하여 사진 변경',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _contentCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '내용을 입력해주세요.',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? '내용을 입력하세요' : null,
            ),
          ],
        ),
      ),
    );
  }
}
