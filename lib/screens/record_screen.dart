import 'package:flutter/material.dart';

class RecordScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('개인운동 기록'),
      ),
      body: Center(
        child: Text(
          '여기에 운동 기록 UI 작성',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
