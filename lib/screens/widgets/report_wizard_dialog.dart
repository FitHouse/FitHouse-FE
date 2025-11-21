import 'package:flutter/material.dart';
import 'package:fithouse/constants/colors.dart';
import '../../api/http_client.dart' show baseUrl, postJson;

class ReportWizardDialog extends StatefulWidget {
  final String photoId;
  final int authorId;
  final String authorName;

  const ReportWizardDialog({
    super.key,
    required this.photoId,
    required this.authorId,
    required this.authorName,
  });

  @override
  State<ReportWizardDialog> createState() => _ReportWizardDialogState();
}

class _ReportWizardDialogState extends State<ReportWizardDialog> {
  static const double _dialogMaxWidth = 420;
  static const double _dialogBaseHeight = 420;
  static const double _dialogExtraForOther = 120;
  static const _reasonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );


  static const List<_ReasonItem> _reasons = <_ReasonItem>[
    _ReasonItem('SPAM',    '스팸/도배성 글이에요'),
    _ReasonItem('ABUSE',   '욕설, 비방, 혐오, 차별 등의 내용이 있어요'),
    _ReasonItem('PRIVACY', '타인의 개인정보를 노출/유포하고 있어요'),
    _ReasonItem('OTHER',   '기타'),
  ];

  String? _selected; // 선택 사유 키
  final _etcController = TextEditingController();
  bool _goNext = false;     // 1단계 → 2단계
  bool _alsoBlock = false;  // 함께 차단
  bool _submitting = false; // 제출중

  // 버튼 스타일
  ButtonStyle get _primaryBtn => FilledButton.styleFrom(
    backgroundColor: buttonGreen,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  ButtonStyle get _secondaryOutlineBtn => OutlinedButton.styleFrom(
    foregroundColor: Colors.black, // 취소/이전 텍스트 검정
    side: BorderSide(color: buttonGreen.withOpacity(0.95), width: 1),
    minimumSize: const Size.fromHeight(44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  @override
  void dispose() {
    _etcController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;

    final isOther = _selected == 'OTHER';
    final details = isOther ? _etcController.text.trim() : null;

    setState(() => _submitting = true);
    try {
      // 1) 신고
      final res = await postJson('$baseUrl/api/community/reports', {
        'photoId': int.tryParse(widget.photoId) ?? widget.photoId,
        'reason': _selected,
        if (details != null && details.isNotEmpty) 'details': details,
      });

      if (res.statusCode != 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 실패: ${res.statusCode} ${res.body}')),
        );
        setState(() => _submitting = false);
        return;
      }

      // 2) (선택) 차단
      if (_alsoBlock) {
        final blockRes = await postJson('$baseUrl/api/community/blocks', {
          'memberId': widget.authorId,
        });
        if (blockRes.statusCode != 201 && blockRes.statusCode != 204) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('차단 실패: ${blockRes.statusCode} ${blockRes.body}')),
          );
          setState(() => _submitting = false);
          return;
        }
        if (!mounted) return;
        Navigator.pop(context, {'blockedMemberId': widget.authorId});
      } else {
        if (!mounted) return;
        Navigator.pop(context); // 신고만 완료
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 중 오류: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 기타 선택 시에만 1단계 높이 확장, 그 외(1단계-기타X/2단계)는 동일
    final bool onStep1 = !_goNext;
    final bool isOther = _selected == 'OTHER';
    final double targetHeight =
    (onStep1 && isOther) ? _dialogBaseHeight + _dialogExtraForOther : _dialogBaseHeight;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: targetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _goNext ? _buildStep2(context) : _buildStep1(context),
          ),
        ),
      ),
    );
  }

  // 1단계: 사유 선택 (+ 기타 입력)
  Widget _buildStep1(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.warning_amber_rounded, size: 44),
        const SizedBox(height: 15),
        const Text(
          '해당 게시물을 신고하는 이유가 무엇인가요?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: _reasons.map((r) {
                final selected = _selected == r.key;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RadioListTile<String>(
                      value: r.key,
                      groupValue: _selected,
                      onChanged: (v) => setState(() => _selected = v),
                      title: Text(r.label, style: _reasonTextStyle),
                      activeColor: buttonGreen, // 선택 색상 통일
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -1), // ★ 간격 압축
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    ),
                    if (r.key == 'OTHER' && selected)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: TextField(
                          controller: _etcController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            hintText: '신고 사유를 입력해 주세요',
                            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
                            filled: true,
                            fillColor: Color(0xFFF5F6F8), // 고객센터 본문과 동일 톤
                            contentPadding: EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6), // ★ 항목 간 여백 축소
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
                onPressed: (_selected == null || _submitting)
                    ? null
                    : () => setState(() => _goNext = true),
                child: const Text('다음'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2단계: 확인 + 안내 + 차단 체크
  Widget _buildStep2(BuildContext context) {
    final label = _reasons.firstWhere((e) => e.key == _selected!).label;

    return Column(
      children: [
        const Icon(Icons.warning_amber_rounded, size: 44),
        const SizedBox(height: 12),
        const Text(
          '신고 내용을 확인해 주세요',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('대상', '${widget.authorName} 님의 게시물'),
                      const SizedBox(height: 8),
                      _kv('사유', label),
                      if (_selected == 'OTHER' && _etcController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _kv('설명', _etcController.text.trim()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '신고는 반대의견을 나타내는 기능이 아닙니다. 신고 사유에 맞지 않는 신고를 했을 경우, 해당 신고는 처리되지 않습니다.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: _alsoBlock,
                  onChanged: _submitting ? null : (v) => setState(() => _alsoBlock = v ?? false),
                  dense: false,
                  activeColor: buttonGreen, // 체크박스 색상 통일
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('이 사용자를 차단할래요'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: _secondaryOutlineBtn,
                onPressed: _submitting ? null : () => setState(() => _goNext = false),
                child: const Text('이전'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: _primaryBtn,
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                  height: 18, width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('신고하기'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(v)),
      ],
    );
  }
}

/// 신고 사유 항목(파일 내부 전용)
class _ReasonItem {
  final String key;
  final String label;
  const _ReasonItem(this.key, this.label);
}

/// 다이얼로그 오픈 헬퍼
Future<Map<String, dynamic>?> showReportWizardDialog(
    BuildContext context, {
      required String photoId,
      required int authorId,
      required String authorName,
    }) {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReportWizardDialog(
      photoId: photoId,
      authorId: authorId,
      authorName: authorName,
    ),
  );
}
