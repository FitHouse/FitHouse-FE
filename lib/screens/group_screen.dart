import 'package:flutter/material.dart';

class GroupScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('그룹 만들기 / 참여'),
      ),
      body: Center(
        child: Text(
          '여기에 그룹 관련 UI 작성',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
