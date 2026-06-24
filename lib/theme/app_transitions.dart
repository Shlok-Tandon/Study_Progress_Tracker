import 'package:flutter/material.dart';

/// One shared transition style for top-level navigation (splash → login/
/// home, login → home) — a soft fade + gentle upward slide, instead of
/// the platform's default abrupt slide-in. Keeping it in one place means
/// every "big" screen change in the app feels the same.
class AppTransitions {
  static PageRouteBuilder fadeThrough(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}