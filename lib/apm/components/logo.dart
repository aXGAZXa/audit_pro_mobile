import 'package:flutter/material.dart';

/// Reusable Morgan Lambert logo widget
class MorganLambertLogo extends StatelessWidget {
  final double height;
  final bool showFullLogo;
  final Color? backgroundColor;

  const MorganLambertLogo({
    super.key,
    this.height = 40,
    this.showFullLogo = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: backgroundColor != null
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: showFullLogo
          ? Image.asset(
              'assets/images/logo.png',
              height: height,
              fit: BoxFit.contain,
            )
          : Image.asset(
              'assets/images/logo_icon.png',
              height: height,
              fit: BoxFit.contain,
            ),
    );
  }

  /// Logo for light backgrounds (app bar, etc.)
  static Widget light({double height = 40}) {
    return MorganLambertLogo(height: height);
  }

  /// Logo for dark backgrounds (drawer header, splash, etc.)
  static Widget dark({double height = 40}) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
    );
  }

  /// Icon only version for compact spaces
  static Widget icon({double size = 32}) {
    return Image.asset(
      'assets/images/logo_icon.png',
      height: size,
      width: size,
      fit: BoxFit.contain,
    );
  }
}
