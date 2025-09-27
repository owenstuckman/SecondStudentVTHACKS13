import 'package:flutter/material.dart';

class TextBubble extends StatelessWidget {
  const TextBubble({
    super.key,
    this.text = '',
    this.icon,
    this.color,
    this.textColor,
    this.iconColor,
    this.borderColor,
    this.margin,
    this.padding,
    this.width,
    this.height,
    this.fontSize = 16,
    this.borderRadius = 20,
    this.borderWidth = 2,
    this.elevation = 2,
    this.onPressed,
    this.iconSize,
    this.spacing = 8,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final Color? iconColor;
  final Color? borderColor;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final double fontSize;
  final double borderRadius;
  final double borderWidth;
  final double elevation;
  final VoidCallback? onPressed;
  final double? iconSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    Widget bubble = _buildBubble(colorScheme);

    if (onPressed != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: bubble,
        ),
      );
    }

    return bubble;
  }

  Widget _buildBubble(ColorScheme colorScheme) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? _getDefaultPadding(),
      decoration: BoxDecoration(
        boxShadow: elevation > 0 ? [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(50),
            blurRadius: elevation,
            offset: Offset(0, elevation / 2),
          ),
        ] : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(
          color: borderColor!,
          width: borderWidth,
        )
            : null,
        color: color ?? colorScheme.primary,
      ),
      child: _buildContent(colorScheme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final bool hasIcon = icon != null;
    final bool hasText = text.isNotEmpty;

    if (!hasIcon && !hasText) {
      return const SizedBox.shrink();
    }

    return IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasIcon) ...[
            Icon(
              icon!,
              color: iconColor ?? textColor ?? colorScheme.onPrimary,
              size: iconSize ?? fontSize * 1.2,
            ),
            if (hasText) SizedBox(width: spacing),
          ],
          if (hasText)
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'Inter',
                  color: textColor ?? colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  EdgeInsets _getDefaultPadding() {
    final bool hasIcon = icon != null;
    final bool hasText = text.isNotEmpty;

    if (hasIcon && hasText) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    } else if (hasIcon) {
      return const EdgeInsets.all(12);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    }
  }
}