import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('로그아웃'),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}