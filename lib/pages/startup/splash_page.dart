import 'dart:convert';
import 'dart:io';

// packages
import 'package:flutter/material.dart';
import 'package:secondstudent/globals/static/static_pages/static_load.dart';
import 'package:secondstudent/pages/startup/welcome_page.dart';
import '../../globals/auth_service.dart';
import '../../globals/database.dart';
import 'home_page.dart';
import 'file_storage.dart';

/*
Splash Page Class
- Displays static loading screen while processing authorization
-
Page to redirect users to the appropriate page depending on the initial auth state.
- Ensures auth, if not, forces auth, which improves security. Also allows for RLS to be implemented properly.
- If no auth, show user signup page
- If auth, continue to home page
 */

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    //Checks file existance
    _redirect();
  }

  //Redirects based on auth state
  Future<void> _redirect() async {
    bool folderExists = false;

    final filePath = '../../../devFolder/storage.json';

    // Read the file
    final file = File(filePath);
    if (await file.exists()) {
      final contents = await file.readAsString();

      // Decode the JSON
      final data = jsonDecode(contents);
      String pathValue = data['path'];

      if (pathValue.isNotEmpty) {
        folderExists = true;
      }

      if (!folderExists) {
        //Removes all widgets from navigation and pushes signup page
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => FileStorage()),
            (route) => false,
          );
        }
      } else {
        //Fetches db
        await DataBase.init();
        if (mounted) {
          //Removes all widgets from navigation and pushes home page
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => HomePage()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StaticLoad();
  }
}
