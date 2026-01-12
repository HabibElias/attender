import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import 'auth_page.dart';
import 'home_page.dart';
import 'profile_setup_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();

    // Defer auth check to after first frame to avoid jank
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  Future<void> _checkSession() async {
    // Tiny delay to allow splash animation to be visible
    await Future.delayed(const Duration(milliseconds: 500));

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Persist basic user info (if not already stored)
      final box = await Hive.openBox('userBox');
      box.put('id', session.user.id);
      box.put('email', session.user.email);
      box.put('name', session.user.userMetadata?['full_name']);
      // fetch profile from Supabase
      ProfileRecord? profile;
      try {
        profile = await ProfileService.fetchProfile(session.user.id);
      } catch (e) {
        profile = null;
      }
      // Navigate based on profile existence
      if (profile != null) {
        box.put('role', profile.role);
        box.put('profileComplete', true);
        _go(const HomePage());
      } else {
        box.put('profileComplete', false);
        box.delete('role');
        _go(
          ProfileSetupPage(
            userId: session.user.id,
            email: session.user.email,
            name: session.user.userMetadata?['full_name'],
          ),
        );
      }
      return;
    }

    // No session -> try read cached user for UX (optional)
    await Hive.openBox('userBox');
    _go(const AuthPage());
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeIn);
          return FadeTransition(opacity: fade, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F9FF), Color(0xFFFFF1F5)],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'lib/images/attender_icon.png',
              width: 120,
              height: 120,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
