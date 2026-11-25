import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/carevora_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressController.forward();

    // Navigate to landing page '/landing' after loading completes
    _navTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        context.go('/landing');
      }
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEADBFF), // Soft Lilac Top
              Color(0xFFFBF8FF), // Creamy Middle
              Color(0xFFF3E7FF), // Soft Pinkish Purple Bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Top Left Wave Fluid Decoration
            Positioned(
              top: -60,
              left: -40,
              child: Container(
                width: 320,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(200),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Subtle Ambient Floating Dots/Orbs
            Positioned(
              top: 80,
              right: 90,
              child: _buildOrb(14, const Color(0xFFE88BC4).withValues(alpha: 0.3)),
            ),
            Positioned(
              top: 150,
              left: 110,
              child: _buildOrb(10, const Color(0xFF6C3FC5).withValues(alpha: 0.25)),
            ),
            Positioned(
              top: 240,
              right: 40,
              child: _buildOrb(22, const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
            ),
            Positioned(
              top: 310,
              left: 35,
              child: _buildOrb(8, const Color(0xFFE88BC4).withValues(alpha: 0.25)),
            ),
            Positioned(
              bottom: 240,
              left: 80,
              child: _buildOrb(18, const Color(0xFFE88BC4).withValues(alpha: 0.2)),
            ),
            Positioned(
              bottom: 180,
              right: 60,
              child: _buildOrb(10, const Color(0xFF6C3FC5).withValues(alpha: 0.25)),
            ),

            // Bottom Left Delicate Leaves Background Graphic
            Positioned(
              bottom: -20,
              left: -20,
              child: CustomPaint(
                size: const Size(220, 260),
                painter: _BotanicalLeavesPainter(),
              ),
            ),

            // Bottom Right Ambient Wave Gradient Overlay
            Positioned(
              bottom: -40,
              right: -30,
              child: Container(
                width: 340,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(240),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE0C9FF).withValues(alpha: 0.45),
                      const Color(0xFFFADAEB).withValues(alpha: 0.35),
                    ],
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                  ),
                ),
              ),
            ),

            // Main Center Column
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Carevora Brand Logo Emblem
                      const CarevoraLogo(
                        variant: LogoVariant.iconOnly,
                        size: 130,
                      ),
                      const SizedBox(height: 28),

                      // CAREVORA Wordmark
                      const Text(
                        'CAREVORA',
                        style: TextStyle(
                          fontFamily: 'Serif',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C1967),
                          letterSpacing: 6.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Heart Divider Line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 1.2,
                            width: 55,
                            color: const Color(0xFFD4BDFC),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.favorite,
                              size: 15,
                              color: Color(0xFFE88BC4),
                            ),
                          ),
                          Container(
                            height: 1.2,
                            width: 55,
                            color: const Color(0xFFD4BDFC),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Tagline 1
                      const Text(
                        'Compassionate Care, Smarter Tomorrow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF332A5C),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline 2
                      const Text(
                        'AI-Powered Elderly Wellness',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF554B7C),
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Custom Rounded Progress Bar
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8DBFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                return LinearProgressIndicator(
                                  value: _progressController.value,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6C3FC5),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Loading Status Text
                      const Text(
                        'Preparing your wellness dashboard...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5E548E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _BotanicalLeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9F7AE0).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.8, size.height * 0.2);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.8, 0, size.height);

    canvas.drawPath(path, paint);

    // Leaf shapes
    final leafPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.3, size.height * 0.7),
        width: 35,
        height: 70,
      ),
      leafPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.55, size.height * 0.45),
        width: 40,
        height: 80,
      ),
      leafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
