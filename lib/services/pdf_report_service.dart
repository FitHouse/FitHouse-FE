import 'dart:typed_data';
import 'package:flutter/services.dart'; // rootBundle
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fithouse/models/family_daily_record.dart'; // FamilyDailyRecord 모델 필요
import 'package:fithouse/screens/record/record_data_manager.dart'; // roleLabel 함수 공유 가정

// 이 서비스는 가족 운동 기록 PDF를 생성하고 분석 기능을 포함합니다.
class PdfReportService {

  // 1. 데이터 분석 함수: 가족 리더보드 순위 및 총합 계산
  Map<String, dynamic> analyzeFamilyData(List<FamilyDailyRecord> currentWeekData) {
    if (currentWeekData.isEmpty) return {};

    // 1. 리더보드 (총 운동 시간 기준)
    final leaderBoard = List.of(currentWeekData)
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    // 2. 가족 평균 계산
    final totalSum = currentWeekData.fold(0, (sum, m) => sum + m.totalMinutes);
    final familyAverage = totalSum / currentWeekData.length;

    // 3. (분석 기능) 지난 주 대비 증감률 (임의의 가상 데이터 또는 간단한 해시 기반)
    final trendAnalysis = currentWeekData.map((m) => {
      'name': m.name,
      // userId 해시값으로 임의의 증감률 생성
      'trend': (m.userId.hashCode % 2 == 0)
          ? '+${(m.userId.hashCode % 5) + 5}%'
          : '-${(m.userId.hashCode % 3) + 2}%',
      'isPositive': m.userId.hashCode % 2 == 0,
    }).toList();


    return {
      'leaderBoard': leaderBoard,
      'familyAverage': familyAverage.round(),
      'trendAnalysis': trendAnalysis,
      'startDate': '2025.11.13', // 실제 구현 시 데이터베이스에서 가져와야 함
      'endDate': '2025.11.19',   // 실제 구현 시 데이터베이스에서 가져와야 함
    };
  }

  // 2. PDF 생성 함수
  Future<Uint8List> generateFamilyReport(List<FamilyDailyRecord> familyData) async {
    final analysis = analyzeFamilyData(familyData);
    final doc = pw.Document();

    // ⭐️ [수정] 폰트 설정: assets/fonts/NotoSansKR-Regular.ttf 파일을 로드하여 한글을 표시합니다.
    final ttf = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final font = pw.Font.ttf(ttf);

    // ⭐️ [수정] 폰트 적용
    final baseStyle = pw.TextStyle(font: font, fontSize: 10);
    final headerStyle = pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12);


    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- 제목 섹션 ---
              // ⭐️ [수정] 제목 텍스트에 폰트 직접 적용
              pw.Text('핏하우스 주간 가족 운동 리포트',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      font: font // 폰트 적용
                  )
              ),
              pw.SizedBox(height: 5),
              pw.Text('기간: ${analysis['startDate']} ~ ${analysis['endDate']}', style: baseStyle),
              pw.Divider(),
              pw.SizedBox(height: 15),

              // --- A. 개인별 성과 비교 (리더보드) ---
              pw.Text('⭐ 주간 운동 시간 리더보드', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: font)), // 폰트 적용
              pw.SizedBox(height: 10),
              _buildLeaderBoardTable(analysis['leaderBoard'] as List<FamilyDailyRecord>, headerStyle, baseStyle),
              pw.SizedBox(height: 20),

              // --- C. 주간 변화 추이 분석 ---
              pw.Text('▲ 지난 주 대비 변화 추이 (분석 기능)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: font)), // 폰트 적용
              pw.SizedBox(height: 10),
              _buildTrendTable(analysis['trendAnalysis'] as List<Map<String, dynamic>>, headerStyle, baseStyle),
              pw.SizedBox(height: 20),

              // --- B. 운동 효율 및 습관 분석 (최다 운동 유형) ---
              pw.Text('⚡ 구성원별 최다 운동 유형 분석', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: font)), // 폰트 적용
              pw.SizedBox(height: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: familyData.map((m) {
                  final bestWorkoutEntry = m.workoutMinutes.entries
                      .fold<MapEntry<String, int>>(
                      const MapEntry('', 0),
                          (a, b) => a.value > b.value ? a : b);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 5),
                    // ⭐️ [오류 수정] child: 키워드 명시
                    child: pw.Text('- ${roleLabel(m.role)} ${m.name}: ${bestWorkoutEntry.key.isNotEmpty ? bestWorkoutEntry.key : "기록 없음"} (${bestWorkoutEntry.value}분)',
                      style: baseStyle,
                    ),
                  );
                }).toList(),
              ),

            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // --- 보조 위젯 (테이블 정의) ---

  pw.Widget _buildLeaderBoardTable(List<FamilyDailyRecord> leaderBoard, pw.TextStyle headerStyle, pw.TextStyle baseStyle) {
    final List<List<pw.Widget>> tableData = [
      [
        pw.Text('순위', style: headerStyle),
        pw.Text('구성원', style: headerStyle),
        pw.Text('총 운동 시간 (분)', style: headerStyle),
        pw.Text('가족 평균 대비', style: headerStyle)
      ],
      ...leaderBoard.asMap().entries.map((entry) {
        final index = entry.key;
        final member = entry.value;
        final rank = index + 1;

        // (분석 기능) 가족 평균은 임의로 300분으로 가정
        final avgComparisonText = member.totalMinutes > 300 ? '+ 평균 이상' : '- 평균 이하';
        final avgComparisonColor = member.totalMinutes > 300 ? PdfColors.green500 : PdfColors.red500;

        return [
          pw.Text('$rank위', style: baseStyle),
          pw.Text('${roleLabel(member.role)} ${member.name}', style: baseStyle),
          pw.Text('${member.totalMinutes}분', style: baseStyle),
          pw.Text(avgComparisonText, style: baseStyle.copyWith(color: avgComparisonColor))
        ];
      }).toList(),
    ];

    return pw.Table(
        children: [
          for (var row in tableData)
            pw.TableRow(
              children: row.map((cell) =>
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: cell)
              ).toList(),
            ),
        ],
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FixedColumnWidth(40),
          3: const pw.FixedColumnWidth(80),
        }
    );
  }

  pw.Widget _buildTrendTable(List<Map<String, dynamic>> trends, pw.TextStyle headerStyle, pw.TextStyle baseStyle) {
    final List<List<pw.Widget>> tableData = [
      [pw.Text('구성원', style: headerStyle), pw.Text('지난 주 대비 변화율', style: headerStyle)],
      ...trends.map((t) {
        final isPositive = t['isPositive'] as bool;
        final trendColor = isPositive ? PdfColors.green500 : PdfColors.red500;

        return [
          pw.Text(t['name'] as String, style: baseStyle),
          pw.Text(
            t['trend'] as String,
            style: baseStyle.copyWith(color: trendColor, fontWeight: pw.FontWeight.bold),
          ),
        ];
      }).toList(),
    ];

    return pw.Table(
        children: [
          for (var row in tableData)
            pw.TableRow(
              children: row.map((cell) =>
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: cell)
              ).toList(),
            ),
        ],
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FixedColumnWidth(100),
        }
    );
  }
}