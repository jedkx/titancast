import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RemoteButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color color;
  final BorderRadius borderRadius;
  final double width;
  final double height;
  final bool isFlat;
  final BoxBorder? border;

  const RemoteButton({
    super.key,
    required this.onTap,
    required this.child,
    required this.color,
    required this.width,
    required this.height,
    this.isFlat = false,
    this.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  const RemoteButton.circle({
    super.key,
    required this.onTap,
    required this.child,
    required this.color,
    required double size,
    this.isFlat = false,
    this.border,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  void _handleTap() {
    HapticFeedback.lightImpact();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.03), width: 1),
        boxShadow: isFlat ? [] : [
          // Dış gölge: Havada süzülme hissi
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          // Üstten vuran hafif ortam ışığı (3D hissiyatı)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: borderRadius,
          highlightColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Center(child: child),
        ),
      ),
    );
  }
}