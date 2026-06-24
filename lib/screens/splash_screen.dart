import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dc_name_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => user == null ? const DcNameScreen() : const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Dance Study Tracker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }
}