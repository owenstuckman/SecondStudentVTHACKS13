import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

import 'package:secondstudent/globals/http_manager.dart';
import 'package:secondstudent/globals/tutorial_system.dart';
import 'package:secondstudent/globals/static/custom_widgets/styled_button.dart';
import 'package:secondstudent/globals/static/themes.dart';
import '../../globals/account_service.dart';
import '../../globals/auth_service.dart';
import '../../globals/static/custom_widgets/icon_circle.dart';
import '../../globals/static/custom_widgets/text_bubble.dart';
import 'package:secondstudent/pages/startup/welcome_page.dart';
import 'package:secondstudent/globals/database.dart';
import 'package:secondstudent/globals/static/custom_widgets/dialogWidget.dart';

class Settings extends StatelessWidget {
  static TextEditingController emailController = TextEditingController(
    text: supabase.auth.currentUser?.email,
  );
  static TextEditingController nameController = TextEditingController(
    text: AccountService.account['name'] ?? '',
  );

  @override
  static bool tutorials = localStorage.getItem("tutorials") != "false";

  final TextEditingController _canvasTokenController = TextEditingController();
  final TextEditingController _canvasDomainController = TextEditingController();

  void _reloadCanvasControllersFromStorage() {
    _canvasTokenController.text = localStorage.getItem('canvasToken') ?? '';
    _canvasDomainController.text = localStorage.getItem('canvasDomain') ?? '';
  }

  Widget _buildOption(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
    Future<void> Function() onTap,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: IconCircle(
        color: color.withAlpha(128),
        icon: icon,
        iconColor: color,
      ),
      title: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: "Nunito",
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: colorScheme.onSurface.withAlpha(192),
      ),
      onTap: onTap,
    );
  }

  Widget canvasWaterMark(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      color: Colors.black,
    );
  }

  Widget _buildTextForm(
    BuildContext context,
    TextEditingController? controller,
    FocusNode? focus,
    String text,
    double width,
    bool edit,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: colorScheme.surface,
          width: width,
          margin: const EdgeInsets.only(right: 8),
          child: TextFormField(
            focusNode: focus,
            enabled: edit,
            ignorePointers: true,
            controller: controller,
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Nunito',
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              labelText: text,
              labelStyle: TextStyle(color: colorScheme.onSurface),
              filled: true,
              fillColor: colorScheme.surface,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: colorScheme.primary),
              ),
            ),
          ),
        ),
        if (edit)
          IconButton(
            onPressed: () {
              if (focus != null) {
                focus.requestFocus();
              }
            },
            icon: Icon(Icons.edit, size: 30, color: colorScheme.primary),
          ),
      ],
    );
  }

  Widget _buildTutorialSettings(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return StatefulBuilder(
      builder: (context, setState) => SizedBox(
        width: mediaQuery.size.width * .6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Switch(
                    value: tutorials,
                    onChanged: (value) {
                      setState(() {
                        tutorials = value;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Display Tutorials",
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: "Nunito",
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StyledButton(
                text: "Reset Tutorials",
                onTap: () {
                  for (String tutorialId in TutorialSystem.tutorialIds) {
                    localStorage.setItem(tutorialId, "false");
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        child: Card(
          color: colorScheme.primaryContainer,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                _buildOption(
                  context,
                  "Account",
                  Icons.manage_accounts_outlined,
                  Colors.cyan,
                  () async {
                    if (await _configureDialog(
                          context,
                          title: "Account Settings",
                          confirmText: "Save",
                        ) ??
                        false) {
                      AccountService.updateProfile({
                        'name': nameController.text,
                        // Removed references to genderController
                      });
                    } else {
                      nameController.text =
                          AccountService.account['name'] ?? '';
                      // Removed references to genderController
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Birthday",
                  Icons.calendar_month_outlined,
                  Colors.pink,
                  () async {
                    DateTime? selectedDate = await showDatePicker(
                      context: context,
                      helpText: "Select Birthday",
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 36500),
                      ),
                      initialDate: DateTime.now(),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            datePickerTheme: DatePickerThemeData(
                              headerHelpStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                fontSize: 25,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selectedDate != null) {
                      // Removed references to bday
                      AccountService.updateProfile({
                        'birthday': selectedDate.toIso8601String(),
                      });
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Tutorials",
                  Icons.help_outline_rounded,
                  Colors.deepPurple,
                  () async {
                    if (await _configureDialog(
                          context,
                          title: "Tutorial Settings",
                          confirmText: "Save",
                          content: _buildTutorialSettings(context),
                        ) ??
                        false) {
                      localStorage.setItem("tutorials", tutorials.toString());
                    } else {
                      tutorials = localStorage.getItem("tutorials") != "false";
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Privacy Policy",
                  Icons.shield_outlined,
                  Colors.blueGrey,
                  () async {
                    HttpManager.launchURL(
                      'https://www.sparkli.com/privacy-policy',
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Logout",
                  Icons.logout_rounded,
                  Colors.grey,
                  () async {
                    if (await _permissionDialog(
                          context,
                          title: "Logout of Account?",
                          confirmText: "Logout",
                        ) ??
                        false) {
                      if (context.mounted) {
                        _logout(context);
                      }
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Delete Account",
                  Icons.delete_forever,
                  Colors.redAccent,
                  () async {
                    if (await _permissionDialog(
                          context,
                          title: "Delete Account Forever?",
                          desc:
                              "Are you sure you would like to delete your account? This action cannot be undone.",
                          confirmText: "Delete Account",
                        ) ??
                        false) {
                      await AuthService.deleteAccount();
                      if (context.mounted) {
                        _logout(context);
                      }
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: colorScheme.onSurface.withAlpha(128)),
                ),
                _buildOption(
                  context,
                  "Canvas",
                  Icons.school_outlined,
                  Colors.blue,
                  () async {
                    _reloadCanvasControllersFromStorage();

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => _buildCanvasSettings(
                        context,
                        domain: _canvasDomainController.text,
                        token: _canvasTokenController.text,
                      ),
                    );
                    if (ok == true) {
                      localStorage.setItem(
                          'canvasToken', _canvasTokenController.text);
                      localStorage.setItem(
                          'canvasDomain', _canvasDomainController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _configureDialog(
    BuildContext context, {
    required String title,
    Widget? content,
    String confirmText = "Confirm",
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "Georama",
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        content: content,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Georama",
                color: colorScheme.secondary,
                fontSize: 20,
              ),
            ),
          ),
          TextBubble(
            text: confirmText,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasSettings(BuildContext context,
      {required String token, required String domain}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.3,
        width: MediaQuery.of(context).size.width * 0.3,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Canvas Settings',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _canvasDomainController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Canvas Domain',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _canvasTokenController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Canvas Token',
                  ),
                ),
                SizedBox(height: 10),
                StyledButton(
                  text: 'Save',
                  onTap: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _permissionDialog(
    BuildContext context, {
    required String title,
    String? desc,
    String confirmText = "Save",
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return _configureDialog(
      context,
      title: title,
      content: desc == null
          ? null
          : Text(
              desc,
              style: TextStyle(
                fontFamily: "Georama",
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
    );
  }

  void _logout(BuildContext context) {
    AuthService.logOutAccount();
    AccountService.account = {};
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomePage()),
      (route) => false,
    );
  }
}
