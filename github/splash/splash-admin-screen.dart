import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// DAKKHO Admin Panel — Splash Screen.
///
/// Lottie animation spelling "DAKKHO" with Purple→Blue accent morph.
/// Deep Navy background. Used as entry point before auth check.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;

  // ─── Admin Color Palette ───────────────────────────────────────
  static const Color deepNavy = Color(0xFF0A0E1A);
  static const Color purpleGlow = Color(0xFF7B2FFF);
  static const Color electricBlue = Color(0xFF007BFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _autoNavigate();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _autoNavigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0D1525),
              Color(0xFF100A28),
              Color(0xFF0A0E1A),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Subtle purple glow ──
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: -50,
              right: -50,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      purpleGlow.withOpacity(0.08),
                      electricBlue.withOpacity(0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ── Main Content ──
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Lottie DAKKHO Animation ──
                  SizedBox(
                    width: 320,
                    height: 240,
                    child: Lottie.asset(
                      'assets/animations/dakkho_splash.json',
                      controller: _lottieController,
                      fit: BoxFit.contain,
                      onLoaded: (composition) {
                        _lottieController
                          ..duration = composition.duration
                          ..forward();
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Admin Label ──
                  _FadeInText(
                    text: 'অ্যাডমিন প্যানেল',
                    style: const TextStyle(
                      color: purpleGlow,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'HindSiliguri',
                    ),
                    delay: const Duration(milliseconds: 1400),
                  ),

                  const SizedBox(height: 4),

                  _FadeInText(
                    text: 'Admin Panel',
                    style: TextStyle(
                      color: textSecondary,
                      letterSpacing: 2.5,
                      fontSize: 12,
                    ),
                    delay: const Duration(milliseconds: 1600),
                  ),

                  const SizedBox(height: 48),

                  _FadeInLoader(delay: const Duration(milliseconds: 1800)),
                ],
              ),
            ),

            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _FadeInText(
                text: 'v1.0.0',
                style: TextStyle(
                  color: textTertiary.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
                delay: const Duration(milliseconds: 2000),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade-in text widget.
class _FadeInText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration delay;

  const _FadeInText({
    required this.text,
    required this.style,
    required this.delay,
  });

  @override
  State<_FadeInText> createState() => _FadeInTextState();
}

class _FadeInTextState extends State<_FadeInText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
      child: Text(widget.text, style: widget.style),
    );
  }
}

/// Fade-in loading indicator.
class _FadeInLoader extends StatefulWidget {
  final Duration delay;
  const _FadeInLoader({required this.delay});

  @override
  State<_FadeInLoader> createState() => _FadeInLoaderState();
}

class _FadeInLoaderState extends State<_FadeInLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          color: purpleGlow.withOpacity(0.5),
        ),
      ),
    );
  }
}
