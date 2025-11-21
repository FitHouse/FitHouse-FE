// lib/screens/report_block_dialog_screen.dart
import 'package:flutter/material.dart';
import 'package:fithouse/constants/colors.dart';
import '../api/http_client.dart' show baseUrl, postJson;

class BlockUserDialog extends StatefulWidget {
  final int targetUserId;      // 차단할 사용자 userId
  final String targetUserName; // UI 표시용

  const BlockUserDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<BlockUserDialog> createState() => _BlockUserDialogState();
}

class _BlockUserDialogState extends State<BlockUserDialog> {
  bool _submitting = false;

  // 신고 팝업과 동일 스타일
  ButtonStyle get _primaryBtn => FilledButton.styleFrom(
    backgroundColor: buttonGreen,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  ButtonStyle get _secondaryOutlineBtn => OutlinedButton.styleFrom(
    foregroundColor: Colors.black,
    side: BorderSide(color: buttonGreen.withOpacity(0.95), width: 1),
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  Future<void> _block() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final res = await postJson('$baseUrl/api/community/blocks', {
        'memberId': widget.targetUserId,
      });

      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 204) {
        Navigator.pop(context, {'blockedMemberId': widget.targetUserId});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('차단 실패: ${res.statusCode} ${res.body}')),
        );
        setState(() => _submitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 44),
              const SizedBox(height: 12),
              const Text(
                '이 사용자를 차단할까요?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.targetUserName} 님을 차단하면 해당 사용자의 게시물이 목록에 나타나지 않아요. '
                      '언제든 설정 > 차단 관리에서 해제할 수 있습니다.',
                  style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: _secondaryOutlineBtn,
                      onPressed: _submitting ? null : () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: _primaryBtn,
                      onPressed: _submitting ? null : _block,
                      child: _submitting
                          ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('차단하기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>?> showBlockUserDialog(
    BuildContext context, {
      required int targetUserId,
      required String targetUserName,
    }) {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlockUserDialog(
      targetUserId: targetUserId,
      targetUserName: targetUserName,
    ),
  );
}
