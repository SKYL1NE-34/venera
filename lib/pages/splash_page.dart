import 'package:flutter/material.dart';

/// Startup overlay that reveals the app name in a handwriting font.
///
/// It is rendered above the app content and is only shown while the app is
/// bootstrapping. The reveal is driven by an [Animation] owned by the caller so
/// it survives rebuilds (e.g. when the theme is applied after `init()`).
class SplashOverlay extends StatelessWidget {
  const SplashOverlay({
    super.key,
    required this.animation,
    required this.background,
    required this.textColor,
  });

  /// Progress of the reveal, from 0 (nothing drawn) to 1 (fully written).
  final Animation<double> animation;

  final Color background;

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      child: AbsorbPointer(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return CustomPaint(
                  size: _splashTextSize(textColor),
                  painter: _HandwritingPainter(
                    progress: animation.value,
                    textColor: textColor,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

const _kSplashText = 'Venera Air';
const _kSplashFont = 'DancingScript';

TextPainter _layoutSplashText(Color color) {
  return TextPainter(
    text: TextSpan(
      text: _kSplashText,
      style: TextStyle(
        fontFamily: _kSplashFont,
        fontSize: 56,
        height: 1.1,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

Size _splashTextSize(Color color) {
  var painter = _layoutSplashText(color);
  return Size(painter.width + 24, painter.height + 24);
}

class _HandwritingPainter extends CustomPainter {
  _HandwritingPainter({required this.progress, required this.textColor});

  final double progress;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    var painter = _layoutSplashText(textColor);
    var dx = (size.width - painter.width) / 2;
    var dy = (size.height - painter.height) / 2;
    var p = progress.clamp(0.0, 1.0);
    var revealWidth = painter.width * p;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(dx, dy, revealWidth, painter.height));
    painter.paint(canvas, Offset(dx, dy));
    canvas.restore();

    // A small "pen tip" following the reveal edge.
    if (p > 0 && p < 1) {
      canvas.drawCircle(
        Offset(dx + revealWidth, dy + painter.height * 0.64),
        3.0,
        Paint()..color = textColor,
      );
    }
  }

  @override
  bool shouldRepaint(_HandwritingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.textColor != textColor;
  }
}
