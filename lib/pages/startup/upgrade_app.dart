import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

//pages
import 'package:secondstudent/pages/startup/splash_page.dart';

/*
Upgrade App Class
- Prompt User to upgrade the app, otherwise continue to splash page

Uses Plugin : https://pub.dev/packages/upgrader
 */

class UpgradeApp extends StatefulWidget {
  const UpgradeApp({super.key});

  @override
  State<UpgradeApp> createState() => _UpgradeAppState();
}

class _UpgradeAppState extends State<UpgradeApp> {
  bool upgradeDialogDisplayed = false;

  @override
  void initState() {
    super.initState();
    _monitorUpgradeDialog();
  }

  void _monitorUpgradeDialog() async {
    await Future.delayed(Duration.zero); // Ensures the widget is built

    if (!Upgrader().shouldDisplayUpgrade()) {
      // If no upgrade dialog is needed, navigate immediately
      _redirect();
    } else {
      setState(() {
        upgradeDialogDisplayed = true;
      });

      // Periodically check if the upgrade dialog has been dismissed
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _redirect();
        }
      });
    }
  }

  void _redirect() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SplashPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // actual alert, see https://pub.dev/packages/upgrader for more information
    return UpgradeAlert(
      dialogStyle: UpgradeDialogStyle.cupertino,
      child: Center(
        child: Text(upgradeDialogDisplayed ? 'Waiting for upgrade check...' : 'Checking...'),
      ),
    );
  }
}
