import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({
    super.key,
    required this.text,
    required this.icon,
    this.cardWidth = 320,
    this.cardHeight = 280,
    this.iconSize = 80,
    this.fontSize = 20,
    this.fontWeight = FontWeight.w600,
    this.padding = const EdgeInsets.all(24),
  });

  final String text;
  final IconData icon;
  final double cardWidth;
  final double cardHeight;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Card(
          color: colorScheme.surface,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIcon(colorScheme),
                const SizedBox(height: 24),
                _buildText(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        color: colorScheme.primary,
        size: iconSize,
      ),
    );
  }

  Widget _buildText(ColorScheme colorScheme) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Delius',
              color: colorScheme.onSurface,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}