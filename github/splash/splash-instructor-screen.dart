import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// DAKKHO Instructor App — Splash Screen.
///
/// Lottie animation spelling "DAKKHO" with Cyan→Green accent morph.
/// Deep Navy background. Nunito 900 as default font.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;

  // ─── Instructor Color Palette ──────────────────────────────────
  static const Color deepNavy = Color(0xFF0A0E1A);
  static const Color cyanAccent = Color(0xFF00F2FF);
  static const Color successGreen = Color(0xFF10B981);
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
              Color(0xFF0A1A20),
              Color(0xFF0A200E),
              Color(0xFF0A0E1A),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Subtle cyan-green glow ──
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
                      cyanAccent.withOpacity(0.08),
                      successGreen.withOpacity(0.04),
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

                  // ── Instructor Label (Nunito 900) ──
                  _FadeInText(
                    text: 'ইনস্ট্রাক্টর',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900, // Nunito 900
                    ),
                    delay: const Duration(milliseconds: 1400),
                  ),

                  const SizedBox(height: 4),

                  _FadeInText(
                    text: 'Instructor',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900, // Nunito 900
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
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: Color(0x806B7280), // textTertiary 50% opacity
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
          color: successGreen.withOpacity(0.5),
        ),
      ),
    );
  }
}
