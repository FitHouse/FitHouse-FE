import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfGenerator {
  static Future<void> generateMonthlyReport({
    required List<dynamic> rawData,
    required String aiAnalysis,
    required int year,
    required int month,
  }) async {
    final pdf = pw.Document();

    // 폰트 로드 (pubspec.yaml에 등록된 경로와 일치해야 함)
    final fontData = await rootBundle.load("assets/fonts/PyeojinGothic-Medium.ttf");
    final ttf = pw.Font.ttf(fontData);

    final baseStyle = pw.TextStyle(font: ttf, fontSize: 10);
    final titleStyle = pw.TextStyle(font: ttf, fontSize: 24);
    final headerStyle = pw.TextStyle(font: ttf, fontSize: 14);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("$year년 $month월 가족 운동 리포트", style: titleStyle),
                  pw.Text("FitHouse", style: baseStyle.copyWith(color: PdfColors.grey)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.green),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("🤖 AI 트레이너의 분석", style: headerStyle.copyWith(color: PdfColors.green900)),
                  pw.Divider(color: PdfColors.green),
                  pw.SizedBox(height: 5),
                  pw.Text(aiAnalysis, style: baseStyle.copyWith(fontSize: 12, lineSpacing: 4)),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            pw.Text("📅 상세 운동 기록", style: headerStyle),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerHeight: 25,
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headerStyle: baseStyle,
              cellStyle: baseStyle,
              headers: ['날짜', '회원ID', '운동 종목', '시간(분)', '만족도'],
              data: rawData.map((data) {
                return [
                  data['date'].toString(),
                  data['userId'].toString(),
                  data['workoutName'].toString(),
                  data['duration'].toString(),
                  data['satisfactionLevel'].toString(),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Family_Report_${year}_$month.pdf',
    );
  }
}