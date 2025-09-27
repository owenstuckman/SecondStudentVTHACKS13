import 'dart:ui';

extension ColorExtension on Color {
  int toInt(){
    int aInt = (a * 255).round();
    int rInt = (r * 255).round();
    int gInt = (g * 255).round();
    int bInt = (b * 255).round();

    return (aInt << 24) | (rInt << 16) | (gInt << 8) | bInt;
  }
}