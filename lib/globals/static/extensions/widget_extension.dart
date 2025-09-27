import 'package:flutter/cupertino.dart';

extension WidgetExtension on Widget {
  /// Widget extension <p>
  /// Returns a FittedBox set to scaleDown wrapping this widget.
  Widget fit({BoxFit fit = BoxFit.scaleDown}) {
    // Returns child wrapped in FittedBox
    return FittedBox(fit: fit, child: this);
  }

  /// Widget extension <p>
  /// Returns a FittedBox set to scaleDown wrapping this widget wrapped in an Expanded box and at a specified alignment.
  /// [Alignment alignment = Alignment.center]: Alignment of widget in Expanded <p>
  /// [EdgeInsets padding = EdgeInsets.zero]: Padding from edges of Expanded <p>
  Widget expandedFit(
      {Alignment alignment = Alignment.center,
        EdgeInsets padding = EdgeInsets.zero}) {
    // Returns child wrapped in FittedBox w/ padding wrapped in Expanded
    return Expanded(
        child: Container(
            margin: padding,
            alignment: alignment,
            child: FittedBox(fit: BoxFit.scaleDown, child: this)));
  }

  /// Widget extension <p>
  /// Returns this widget wrapped in an IntrinsicWidth widget. IntrinsicWidth matches teh size of its child.
  Widget intrinsicFit() {
    return IntrinsicWidth(child: this);
  }

  /// Widget extension <p>
  /// Returns this widget wrapped in a ClipRRECT Widget.
  Widget clip({BorderRadius borderRadius = BorderRadius.zero}){
    return ClipRRect(borderRadius: borderRadius, clipBehavior: Clip.hardEdge, child: this);
  }

  /// Widget extension <p>
  /// Returns this widget wrapped in an Opacity Widget.
  Widget withOpacity(double opacity) {
    return Opacity(opacity: opacity, child: this);
  }
}