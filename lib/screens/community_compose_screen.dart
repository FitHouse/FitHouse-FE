import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/colors.dart';
import '../api/http_client.dart' show baseUrl;

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

  // 공통 스타일
  static const _fieldBg = Color(0xFFF5F6F8);
  // 앱바 색상 (RecordScreen과 동일)
  static const _appBarColor = Color(0xFFA9C18D);

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

    final uri = Uri.parse('$baseUrl/api/community/photos');
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
    final uri = Uri.parse('$baseUrl/api/community/photos/${widget.postId}');
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
      ..headers['Accept'] = 'application/json'
      ..fields['comment'] = newComment;

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
      } catch (_) {}
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
        // [수정] RecordScreen과 동일한 배경색 적용
        backgroundColor: _appBarColor,
        elevation: 0,
        centerTitle: true,
        // [수정] 뒤로가기 버튼 흰색
        leading: const BackButton(color: Colors.white),
        // [수정] 타이틀 흰색 및 굵게
        title: Text(
          isEdit ? '게시글 수정' : '게시글 작성',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(
              // [수정] 버튼 글씨 흰색
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
            ),
            child: _submitting
                ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                // [수정] 로딩바 흰색
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Text(
              '등록',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            // 이미지 영역
            _ImagePickerCard(
              initialImageUrl: widget.initialImageUrl,
              pickedImage: _pickedImage,
              onPick: _pickImage,
              isEdit: isEdit,
            ),
            const SizedBox(height: 20),

            // 내용 입력
            TextFormField(
              controller: _contentCtrl,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '내용을 입력해주세요.',
                hintStyle: TextStyle(color: grey),
                filled: true,
                fillColor: _fieldBg,
                contentPadding: EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력하세요' : null,
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

/// 이미지 선택 카드
class _ImagePickerCard extends StatelessWidget {
  final String? initialImageUrl;
  final File? pickedImage;
  final VoidCallback onPick;
  final bool isEdit;

  const _ImagePickerCard({
    required this.initialImageUrl,
    required this.pickedImage,
    required this.onPick,
    required this.isEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedImage != null || (initialImageUrl ?? '').isNotEmpty;

    return GestureDetector(
      onTap: onPick,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          children: [
            // 배경 카드
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E6E6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),

            // 콘텐츠
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? _buildImage()
                    : _buildEmptyState(context),
              ),
            ),

            // 우측 상단 변경/추가 플로팅 라벨
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasImage ? '탭하여 ${isEdit ? "변경" : "변경/교체"}' : '탭하여 추가',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (pickedImage != null) {
      return Image.file(pickedImage!, fit: BoxFit.cover);
    }
    return Image.network(initialImageUrl!, fit: BoxFit.cover);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.add_a_photo_outlined, size: 44, color: Color(0xFF9AA0A6)),
          SizedBox(height: 8),
          Text(
            '사진을 등록해 주세요.',
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
        ],
      ),
    );
  }
}