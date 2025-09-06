import 'package:flutter/material.dart';
import '../gaze/gaze_models.dart';

/// Ekranda gaze noktasını gösteren overlay widget
class GazeOverlay extends StatelessWidget {
  final GazeFrame gazeFrame;
  final double dotSize;
  final Color dotColor;
  final bool showCrosshair;

  const GazeOverlay({
    super.key,
    required this.gazeFrame,
    this.dotSize = 20.0,
    this.dotColor = Colors.red,
    this.showCrosshair = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ekran boyutlarını al
    final size = MediaQuery.of(context).size;

    // Normalize koordinatları piksele çevir
    final pixelX = gazeFrame.x * size.width;
    final pixelY = gazeFrame.y * size.height;

    return IgnorePointer(
      child: Stack(
        children: [
          // Ana nokta
          Positioned(
            left: pixelX - dotSize / 2,
            top: pixelY - dotSize / 2,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // Crosshair (opsiyonel)
          if (showCrosshair) ...[
            // Yatay çizgi
            Positioned(
              left: 0,
              top: pixelY - 0.5,
              child: Container(
                width: size.width,
                height: 1,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            // Dikey çizgi
            Positioned(
              left: pixelX - 0.5,
              top: 0,
              child: Container(
                width: 1,
                height: size.height,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ],

          // Güven göstergesi (halka)
          Positioned(
            left: pixelX - dotSize,
            top: pixelY - dotSize,
            child: Container(
              width: dotSize * 2,
              height: dotSize * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getConfidenceColor(gazeFrame.confidence),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Güven seviyesine göre renk belirle
  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) {
      return Colors.green.withOpacity(0.5);
    } else if (confidence > 0.5) {
      return Colors.yellow.withOpacity(0.5);
    } else {
      return Colors.red.withOpacity(0.5);
    }
  }
}

/// Animasyonlu gaze overlay
class AnimatedGazeOverlay extends StatefulWidget {
  final GazeFrame gazeFrame;
  final Duration animationDuration;
  final double dotSize;
  final Color dotColor;

  const AnimatedGazeOverlay({
    super.key,
    required this.gazeFrame,
    this.animationDuration = const Duration(milliseconds: 100),
    this.dotSize = 20.0,
    this.dotColor = Colors.red,
  });

  @override
  State<AnimatedGazeOverlay> createState() => _AnimatedGazeOverlayState();
}

class _AnimatedGazeOverlayState extends State<AnimatedGazeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pixelX = widget.gazeFrame.x * size.width;
    final pixelY = widget.gazeFrame.y * size.height;

    return IgnorePointer(
      child: AnimatedPositioned(
        duration: widget.animationDuration,
        curve: Curves.easeOutCubic,
        left: pixelX - widget.dotSize / 2,
        top: pixelY - widget.dotSize / 2,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(
                  color: widget.dotColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
