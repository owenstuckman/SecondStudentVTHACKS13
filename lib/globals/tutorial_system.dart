import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:secondstudent/pages/settings/settings.dart';
import 'package:secondstudent/globals/static/extensions/build_context_extension.dart';
import 'package:secondstudent/globals/static/extensions/widget_extension.dart';
import 'package:secondstudent/globals/static/custom_widgets/styled_button.dart';

class TutorialSystem {
  static List<String> tutorialIds = [
    'tutorial_custom',
    'tutorial_saved',
    'tutorial_notes',
  ];

  TutorialSystem({
    required this.id,
    required this.title,
    this.description,
    this.icon,
  });

  final String id;
  final String title;
  final String? description;
  final IconData? icon;

  bool run(BuildContext context, bool override) {
    if ((localStorage.getItem(id) != 'true' && Settings.tutorials) ||
        override) {
      context.pushPopup(_buildCard(context));
      localStorage.setItem(id, "true");
      return true;
    }
    return false;
  }

  Widget _buildCard(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return Center(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: colorScheme.tertiary.withAlpha(224),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * .625,
            maxWidth: mediaQuery.size.width * .625,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 48, color: colorScheme.onTertiary).fit(),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Nunito",
                  height: 0.9,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onTertiary,
                ),
              ),
              const SizedBox(height: 4),
              if (description != null)
                Text(
                  description ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Nunito",
                    fontSize: 16,
                    color: colorScheme.onTertiary,
                  ),
                ),
              const SizedBox(height: 16),
              StyledButton(
                text: "Needed This",
                width: mediaQuery.size.width / 3,
                height: 40,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
