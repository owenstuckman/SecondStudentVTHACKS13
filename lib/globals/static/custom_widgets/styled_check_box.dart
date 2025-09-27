import 'package:flutter/material.dart';

class StyledCheckBox extends StatelessWidget {
  const StyledCheckBox({
    super.key,
    required this.value,
    this.text = '',
    this.onPressed,
    this.textWidth,
    this.checkboxScale = 1.5,
    this.fontSize = 16,
    this.spacing = 12,
  });

  final bool value;
  final String text;
  final VoidCallback? onPressed;
  final double? textWidth;
  final double checkboxScale;
  final double fontSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCheckbox(colorScheme),
            if (text.isNotEmpty) ...[
              SizedBox(width: spacing),
              _buildText(colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Transform.scale(
      scale: checkboxScale,
      child: AbsorbPointer(
        child: Checkbox(
          value: value,
          activeColor: colorScheme.primary.withAlpha(25),
          checkColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          side: WidgetStateBorderSide.resolveWith(
                (states) => BorderSide(
              width: 1.5,
              color: value
                  ? colorScheme.primary
                  : colorScheme.outline,
            ),
          ),
          onChanged: null,
        ),
      ),
    );
  }

  Widget _buildText(ColorScheme colorScheme) {
    Widget textWidget = Text(
      text,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontFamily: 'Georama',
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );

    if (textWidth != null) {
      return SizedBox(
        width: textWidth,
        child: textWidget,
      );
    }

    return Flexible(child: textWidget);
  }
}