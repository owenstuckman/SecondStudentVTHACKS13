import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  const Logo({
    super.key,
    this.blur = 0,
    this.fontSize = 25,
    this.fontWeight = FontWeight.w600,
  });

  final double blur;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Text(
      "SECOND STUDENT",
      style: TextStyle(
        shadows: [
          Shadow(
            blurRadius: blur,
            color: colorScheme.onPrimary,
          ),
        ],
        color: colorScheme.primary,
        fontFamily: 'ProstoOne',
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }

}