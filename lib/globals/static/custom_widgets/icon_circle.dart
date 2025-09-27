import 'package:flutter/material.dart';

class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.color,
    required this.icon,
    this.radius = 20.5,
    this.padding = 5.5,
    this.onPressed,
    this.iconColor = Colors.black,
  });

  final Color color;
  final IconData icon;
  final double radius;
  final double padding;
  final VoidCallback? onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Icon(
          icon,
          color: iconColor,
          size: radius * 2 - padding,
        ),
      ),
    );
  }
}